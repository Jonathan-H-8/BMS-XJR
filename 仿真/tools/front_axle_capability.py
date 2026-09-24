"""
前驱轮边电机能力核算 —— Maytech MTI120116-HA-SF + MKSESC 75200 V2
====================================================================
用途：对应申报书"阶段一 —— 结合赛车实际需求，计算完成目标圈速与总里程所需电量"。
      这一步先回答三个问题（不涉及电池，先把"电驱能力"这条链打通）：

    Q1  前驱能贡献多少驱动力？要达到目标助力比例，需要多大减速比？
    Q2  接入前驱后，圈速 / 直线加速能提升多少？
    Q3  对应电池侧要多大的电压、电流、功率？→ 这是下传 BMS 指标的入口

物理约定
--------
  电机（DC 等效模型，QSS 级精度足够）：
        V_bus = Ke·ω + R_eq·I          电压/转速约束
        T     = Kt·I                   转矩/电流约束
        P_mech= T·ω

  整车纵向动力学：沿用底盘组 QSS 内核（qss_ref.py），只把"驱动极限"从
      "纯后驱（仅发动机 37 kW）" 扩成 "后驱发动机 + 前置两轮边电机"。

  ★ 标注 [待确认] 的量为必须向电机厂/车队补齐的输入，当前用占位值。
"""

import numpy as np
import sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qss_ref as Q

G = Q.G
R_EFF = Q.R_EFF          # 0.204 m，底盘组定义的有效滚动半径

# ================================================================ 电机参数
# 来源：3194560061MTI120116-HA-SF 中文规格(2).pdf 第 1 页
# 注意：MTI120116-HA-SF 只是"带霍尔 + 水冷"这个版本代号，KV 未编入型号，
#       下表是整个 MTI120116 系列 6 个 KV 档位的规格，需确认实际订购的是哪一档。
MOTOR = {
    # KV : Kt[N·m/A]  Vmax[V]  Ipk[A]  Pmax[W]  Tpk[N·m]  Trated[N·m]  eta_max  mass[kg]
    275: dict(Kt=0.0392, Vmax=32, Ipk=480, Pmax=15300, Tpk=18.8, Trated=12.8, eta=0.89, mass=4.1),
    230: dict(Kt=0.0475, Vmax=39, Ipk=430, Pmax=17500, Tpk=20.3, Trated=13.5, eta=0.87, mass=4.2),
    200: dict(Kt=0.0547, Vmax=52, Ipk=380, Pmax=15000, Tpk=20.6, Trated=13.6, eta=0.90, mass=4.4),
    173: dict(Kt=0.0612, Vmax=52, Ipk=340, Pmax=17500, Tpk=20.8, Trated=13.8, eta=0.91, mass=4.3),
    150: dict(Kt=0.0692, Vmax=60, Ipk=300, Pmax=17800, Tpk=21.8, Trated=14.3, eta=0.91, mass=4.2),
    100: dict(Kt=0.0794, Vmax=90, Ipk=220, Pmax=18800, Tpk=22.6, Trated=14.7, eta=0.88, mass=4.5),
}
# 公告的标准款只有 100KV / 150KV 两档（Maytech 官网）；其余为可定制。

# ================================================================ 电调参数
# 来源：Makerbase VESC 75V200A V2 规格书
ESC = dict(
    Vmin=14.0, Vmax=84.0,
    Icont_50V=200.0,     # 50V 时持续 200A
    Icont_75V=150.0,     # 75V 时持续 150A（持续时间取决于外部散热）
    Ipk=300.0,           # 最大脉冲 300A
    erpm_max=150000,
    mass=0.35,
)


def esc_icont(V_bus):
    """电调持续电流随母线电压线性内插（规格只给了 50V/75V 两点）"""
    return float(np.clip(np.interp(V_bus, [50.0, 75.0], [200.0, 150.0]), 0.0, 200.0))


# ================================================================ 通用默认值
ETA_GEAR = 0.95          # 减速机构效率（同步带/链传动）
ETA_EM = 0.88            # 电机+电调综合效率 [待确认]：规格书只给"最高效率"，无 MAP
R_EQ = 0.030             # DC 等效内阻 [Ω] [待确认]：仅用于"电压—转速"约束估算
V_BUS = 50.0             # 母线电压占位：48V 标称（15S LFP 满充 54.75V）取 50V
BUS_PACK_S = 15          # 48V 标称 = 15S LFP（3.2V × 15 = 48V，满充 54.75V）


# ================================================================ 单轮电机出力
def wheel_force(v_car, ratio, kv, V_bus=V_BUS, i_limit=None):
    """
    给定车速 v_car[m/s]、减速比 ratio、电机 KV，返回单个前轮的
        (轮上驱动力[N], 电机相电流[A], 电机转矩[N·m], 电机转速[rad/s], 电机机械功率[W])
    限制依次为：电调峰值电流 → 电机峰值电流 → 电机峰值转矩 → 母线电压（反电势）→ 电调持续电流
    """
    mo = MOTOR[kv]
    Kt = mo["Kt"]
    w_m = ratio * v_car / R_EFF                       # 电机机械角速度 [rad/s]
    # 电压约束（反电势顶满后电流必须下降，形成恒功率区）
    I_volt = max(0.0, (V_bus - Kt * w_m) / R_EQ)
    # 电流约束
    I_cap = mo["Ipk"] if i_limit is None else min(mo["Ipk"], i_limit)
    I = min(I_cap, I_volt)
    T = min(Kt * I, mo["Tpk"])
    I = T / Kt                                        # 转矩封顶后回写电流
    F = T * ratio * ETA_GEAR / R_EFF                  # 轮上驱动力 [N]
    P_mech = T * w_m                                  # 单台电机机械功率 [W]
    return F, I, T, w_m, P_mech


def axle_force(v_car, ratio, kv, bus_pack_S=BUS_PACK_S, use_cont=False):
    """前轴（两台轮边电机）合计驱动力 [N] 及电侧信息"""
    V_bus = 3.2 * bus_pack_S                          # 用标称电压，保守
    i_lim = esc_icont(V_bus) if use_cont else ESC["Ipk"]
    F1, I1, T1, w1, P1 = wheel_force(v_car, ratio, kv, V_bus=V_bus, i_limit=i_lim)
    F_axle = 2 * F1
    P_mech = 2 * P1
    P_elec = P_mech / ETA_EM
    I_bus = P_elec / V_bus
    return dict(F=F_axle, I_ph=I1, T=T1, w_motor=w1, P_mech=P_mech,
                P_elec=P_elec, I_bus=I_bus, V_bus=V_bus, F1=F1)


# ================================================================ 混合动力 GGV
def hybrid_ggv(ratio=None, kv=150, p=None, use_cont=False, bus_pack_S=BUS_PACK_S,
               p_budget=None):
    """
    在底盘组 GGV 基础上，把驱动极限从"后驱发动机"扩为
        F_total = F_rear(发动机, 受后轴附着+37kW功率限制)
                + F_front(两轮边电机, 受电机/电调/前轴附着限制)
    ratio=None 表示纯后驱（复现底盘组原结果，用于对照）。
    p_budget : 前驱电功率预算上限 [W]（电池侧），None = 不限制（用电机自身能力）
    """
    q = dict(Q.P)
    if p:
        q.update(p)

    m, L, h = q["m"], q["L"], q["h"]
    a_load = q["cog_f"] * L
    b_load = L - a_load
    m_eff = m + 4 * Q.IW / R_EFF ** 2

    def mu_x(Fz):
        return q["kx"] * np.maximum(0.0, q["mu_x0"] + q["k_mu_x"] * np.asarray(Fz))

    V_kmh = np.linspace(0.5, q["V_max_kmh"], 25)
    V = V_kmh / 3.6
    Ax = np.zeros(len(V))
    Ff = np.zeros(len(V))
    Ib = np.zeros(len(V))

    for i in range(len(V)):
        D = 0.5 * Q.RHO * q["CDA"] * V[i] ** 2
        Fz_af = 0.5 * Q.RHO * q["CLA"] * V[i] ** 2 * q["aeroDistF"]
        Fz_ar = 0.5 * Q.RHO * q["CLA"] * V[i] ** 2 * (1 - q["aeroDistF"])
        Fz0_f = m * G * (b_load / L) + Fz_af
        Fz0_r = m * G * (a_load / L) + Fz_ar

        ax = 5.0
        for _ in range(40):
            dFz = m * ax * h / L
            Fz_f1 = max(0.0, (Fz0_f - dFz) / 2)       # 单前轮垂载
            Fz_r1 = max(0.0, (Fz0_r + dFz) / 2)       # 单后轮垂载
            # 后轴：发动机，受附着 + 37kW 功率限制
            Fx_rear = 2 * mu_x(Fz_r1) * Fz_r1
            F_rear = min(Fx_rear, q["power_max"] / max(V[i], 1.0))
            # 前轴：轮边电机
            if ratio is None:
                F_front = 0.0
            else:
                af = axle_force(V[i], ratio, kv, bus_pack_S=bus_pack_S, use_cont=use_cont)
                F_cap = af["F"]
                if p_budget is not None:
                    F_cap = min(F_cap, p_budget * ETA_EM / max(V[i], 0.5))
                F_front = min(F_cap, 2 * mu_x(Fz_f1) * Fz_f1)   # 电机能力 vs 前轴附着
            F_tot = F_rear + F_front
            ax_new = (F_tot - D) / m_eff
            if abs(ax_new - ax) < 1e-5:
                break
            ax = ax_new
        Ax[i] = ax
        if ratio is not None:
            af = axle_force(V[i], ratio, kv, bus_pack_S=bus_pack_S, use_cont=use_cont)
            f_cap = af["F"]
            if p_budget is not None:
                f_cap = min(f_cap, p_budget * ETA_EM / max(V[i], 0.5))
            Ff[i] = min(f_cap, 2 * mu_x(Fz_f1) * Fz_f1)
            Ib[i] = Ff[i] * V[i] / ETA_EM / (3.2 * bus_pack_S)

    return V_kmh, Ax, Ff, Ib


# ================================================================ 直线加速事件
def accel_event(distance=75.0, ratio=None, kv=150, p=None, use_cont=False, p_budget=None):
    """FSAE 直线加速（75 m 静止起步）时间与出线速度。"""
    q = dict(Q.P)
    if p:
        q.update(p)
    _, Ax, _, _ = hybrid_ggv(ratio=ratio, kv=kv, p=q, use_cont=use_cont, p_budget=p_budget)
    V_kmh = np.linspace(0.5, q["V_max_kmh"], 25)
    m = q["m"]
    m_eff = m + 4 * Q.IW / R_EFF ** 2

    x, v, t = 0.0, 0.5 / 3.6, 0.0
    dt = 0.002
    while x < distance and t < 60:
        ax = np.interp(v * 3.6, V_kmh, Ax)
        v = max(v + ax * dt, 0.05)
        x += v * dt
        t += dt
    return t, v * 3.6


# ================================================================ 主程序
def main():
    line = "=" * 78
    print(line)
    print("前驱轮边电机能力核算  |  Maytech MTI120116-HA-SF  ×2  +  MKSESC 75200 V2 ×2")
    print(line)

    print("\n【0】电调约束（母线电压 → 可用持续电流）")
    print(f"  {'V_bus[V]':>10}{'I_cont[A]':>12}{'对应电功率[kW]':>16}   备注")
    for Vb in [48.0, 50.0, 54.0, 54.75, 58.4]:
        ic = esc_icont(Vb)
        tag = ""
        if abs(Vb - 54.75) < 0.01:
            tag = "15S LFP 满充"
        if abs(Vb - 58.4) < 0.01:
            tag = "16S LFP 满充"
        print(f"  {Vb:>10.2f}{ic:>12.1f}{Vb*ic/1000:>16.1f}   {tag}")
    print("  → 母线 48V 标称时，单台电调持续约 200A；两台合计电池侧约 400A（峰值 600A）")

    print("\n【1】单台电机在不同 KV 下的转矩/电流特性")
    print(f"  {'KV':>6}{'Kt[N·m/A]':>12}{'I_pk[A]':>9}{'T_pk[N·m]':>11}"
          f"{'P_max[kW]':>11}{'V_max[V]':>10}{'重量[kg]':>10}")
    for kv in [100, 150, 173, 200, 230, 275]:
        mo = MOTOR[kv]
        print(f"  {kv:>6}{mo['Kt']:>12.4f}{mo['Ipk']:>9}{mo['Tpk']:>11.1f}"
              f"{mo['Pmax']/1000:>11.1f}{mo['Vmax']:>10}{mo['mass']:>10.1f}")

    print("\n【2】★ 需要多大减速比？（前轴峰值驱动力 / 整车最大牵引需求）")
    # 整车最大牵引需求 = ax_max 时的总驱动力（用后驱 GGV 的峰值加速度近似）
    Vk0, Ax0, _, _ = hybrid_ggv(ratio=None)
    F_need = Q.P["m"] * np.max(Ax0)
    print(f"  纯后驱极限加速度 {np.max(Ax0)/G:.2f} g  →  总牵引力需求 ≈ {F_need:.0f} N")
    print("  （这是后驱能给出的上限，前驱是在此之上叠加，不是替代）\n")

    for kv in [150, 100]:
        print(f"  ── KV = {kv} ──")
        print(f"  {'减速比i':>8}{'v=10km/h':>11}{'v=30km/h':>11}{'v=50km/h':>11}"
              f"{'v=70km/h':>11}{'电机顶速[km/h]':>15}")
        for ratio in [1, 2, 3, 4, 5, 6, 8]:
            row = ""
            for vk in [10, 30, 50, 70]:
                af = axle_force(vk / 3.6, ratio, kv)
                row += f"{af['F']:>11.0f}"
            v_top = MOTOR[kv]["Vmax"] / MOTOR[kv]["Kt"] * R_EFF / ratio
            print(f"  {ratio:>8}{row}{v_top*3.6:>15.1f}")
        print()

    print("【3】给定减速比 → 助力比例 λ（前轴力 / 总牵引力需求）")
    print(f"  {'减速比i':>8}{'λ@10km/h':>11}{'λ@30km/h':>11}{'λ@50km/h':>11}")
    for ratio in [2, 3, 4, 5, 6]:
        row = ""
        for vk in [10, 30, 50]:
            af = axle_force(vk / 3.6, ratio, 150)
            row += f"{af['F']/F_need*100:>10.1f}%"
        print(f"  {ratio:>8}{row}")

    print("\n【4】接入前驱后：圈速与直线加速（并计入增重代价）")
    tr = Q.load_track(
        r"E:\FSAE_XJRT\BMS\仿真\refs_chassis"
        r"\西安交通大学毅行赛车队底盘组matlab动力学程序"
        r"\GGV_LTS_SensitivityAnsysis_V4.0\2026_ChengDu.txt"
    )
    print(f"  赛道：{tr['L']:.1f} m/圈   整车基准质量 {Q.P['m']:.0f} kg")
    print(f"  {'方案':>18}{'整车质量':>10}{'圈速[s]':>10}{'Δ圈速':>9}"
          f"{'75m加速[s]':>12}{'Δ加速':>9}")
    t_base = accel_event(75.0, ratio=None)[0]
    lap_base = Q.simulate_lap(tr, *[Q.ggv_limits()[i] for i in [0, 1, 2, 3]])
    print(f"  {'纯后驱(基准)':>18}{240:>10.0f}{lap_base['t']:>10.2f}{'—':>9}"
          f"{t_base:>12.3f}{'—':>9}")
    ADD_MASS = 2 * MOTOR[150]["mass"] + 2 * ESC["mass"] + 1.5   # 电机×2+电调×2+支架/减速机构
    for tag, ratio, kv, dm in [("前驱 i=3 150KV", 3, 150, 0.0),
                               ("前驱 i=5 150KV", 5, 150, 0.0),
                               ("前驱 i=6 150KV", 6, 150, 0.0),
                               ("前驱 i=5 100KV", 5, 100, 0.0),
                               ("前驱 i=5 +增重", 5, 150, ADD_MASS),
                               ("前驱 i=3 +增重", 3, 150, ADD_MASS)]:
        pp = dict(Q.P); pp["m"] = Q.P["m"] + dm
        Vk, Ax, _, _ = hybrid_ggv(ratio=ratio, kv=kv, p=pp)
        _, Ay, Ab, _ = Q.ggv_limits(p=pp)
        lap = Q.simulate_lap(tr, Vk, Ay, Ab, Ax, p=pp)
        ta, va = accel_event(75.0, ratio=ratio, kv=kv, p=pp)
        print(f"  {tag:>18}{pp['m']:>10.0f}{lap['t']:>10.2f}"
              f"{lap['t']-lap_base['t']:>+9.2f}{ta:>12.3f}{ta-t_base:>+9.3f}")
    print(f"  （增重 = 2×电机 {2*MOTOR[150]['mass']:.1f} + 2×电调 {2*ESC['mass']:.1f} "
          f"+ 支架/减速机构 1.5 ≈ {ADD_MASS:.1f} kg，占整车 {ADD_MASS/240*100:.1f}%）")

    print("\n【5】★ 前驱电量需求（单圈 → 耐久赛 22 km）")
    print("  方法：先算本圈总轮上牵引能量 E_traction，再按前驱承担比例 λ 分配。")
    print("        λ 是 S3/S4 要定的电驱介入策略；此处扫 λ 给出区间，不是最终值。")
    print("        不含低压 12V 负载，回收另计（需 S5 建模附着力/电机/电池三重限制）。")

    def lap_traction_energy(lap, p=None):
        q = dict(Q.P)
        if p:
            q.update(p)
        m_eff = q["m"] + 4 * Q.IW / R_EFF ** 2
        v = lap["v"] / 3.6
        vh = 0.5 * (v[:-1] + v[1:])
        axh = 0.5 * (lap["ax"][:-1] + lap["ax"][1:])
        F = m_eff * axh + 0.5 * Q.RHO * q["CDA"] * vh ** 2 + q["crr"] * q["m"] * G
        dt = lap["dt"]
        return (float(np.sum(np.clip(F, 0, None) * vh * dt)) / 3600,
                float(np.sum(np.clip(F, None, 0) * vh * dt)) / 3600)

    Q.P.setdefault("crr", 0.015)
    LAP_KM = 22.0
    laps = LAP_KM * 1000 / tr["L"]
    print(f"  耐久赛圈数 = {laps:.1f} 圈（22 km / {tr['L']:.1f} m）\n")
    print(f"  {'方案':>14}{'单圈总牵引[Wh]':>16}{'λ':>6}{'单圈前驱[Wh]':>14}"
          f"{'电侧[kWh]':>12}{'22km电侧[kWh]':>15}")
    for tag, ratio, kv in [("i=3 150KV", 3, 150), ("i=5 150KV", 5, 150), ("i=6 150KV", 6, 150)]:
        Vk, Ax, _, _ = hybrid_ggv(ratio=ratio, kv=kv)
        _, Ay, Ab, _ = Q.ggv_limits()
        lap = Q.simulate_lap(tr, Vk, Ay, Ab, Ax)
        Ep, En = lap_traction_energy(lap)
        for lam in [0.25, 0.35]:
            Ef = Ep * lam
            print(f"  {tag:>14}{Ep:>16.1f}{lam:>6.2f}{Ef:>14.1f}"
                  f"{Ef/ETA_EM/1000:>12.3f}{Ef/ETA_EM*laps/1000:>15.2f}")
    print("  ※ 22 km 全程若允许换电池，单块容量按半程 11 km 设计（需确认赛规）")

    print("\n【6】★ 电池侧电流/功率需求（下传 BMS 指标的入口）")
    print("  —— 取 i=5 / 150KV，这是兼顾助力与可行性的中间方案（前驱能力上限）")
    print(f"  {'车速[km/h]':>11}{'前轴力[N]':>11}{'单机相电流[A]':>14}"
          f"{'前轴电功率[kW]':>15}{'母线电流[A]':>13}")
    for vk in [10, 20, 30, 40, 50, 60, 70, 85]:
        af = axle_force(vk / 3.6, 5, 150)
        print(f"  {vk:>11}{af['F']:>11.0f}{af['I_ph']:>14.0f}"
              f"{af['P_elec']/1000:>15.1f}{af['I_bus']:>13.0f}")
    print("  → 母线电流在 50~70 km/h 区间达到 330~470 A，这是 BMS 量程设计的关键约束")

    print("\n【7】★ 前驱功率预算扫描（真正的设计旋钮）")
    print("  —— 前驱能力上限由电机决定，但电池侧的电流/重量由功率预算决定。")
    print(f"  {'功率预算':>10}{'i=5圈速[s]':>13}{'Δ圈速':>9}{'75m加速[s]':>13}"
          f"{'Δ加速':>9}{'前轴力峰值[N]':>14}{'母线峰值I[A]':>14}")
    Vk0, Ax0, _, _ = hybrid_ggv(ratio=None)
    _, Ay0, Ab0, _ = Q.ggv_limits()
    lap0 = Q.simulate_lap(tr, Vk0, Ay0, Ab0, Ax0)
    t0 = accel_event(75.0, ratio=None)[0]
    for pb_kw in [4, 6, 8, 10, 15, None]:
        tag = "不限(电机)" if pb_kw is None else f"{pb_kw} kW"
        pb = None if pb_kw is None else pb_kw * 1000
        Vk, Ax, Ff, Ib = hybrid_ggv(ratio=5, kv=150, p_budget=pb)
        lap = Q.simulate_lap(tr, Vk, Ay0, Ab0, Ax)
        ta, va = accel_event(75.0, ratio=5, kv=150, p_budget=pb)
        print(f"  {tag:>10}{lap['t']:>13.2f}{lap['t']-lap0['t']:>+9.2f}"
              f"{ta:>13.3f}{ta-t0:>+9.3f}{np.max(Ff):>14.0f}{np.max(Ib):>14.0f}")

    print("\n【8】整车增重对圈速的反噬（选型的隐藏代价）")
    print(f"  {'整车质量[kg]':>13}{'纯后驱圈速[s]':>15}{'对比240kg':>12}")
    for m_extra in [0, 10, 20, 30, 40]:
        pp = dict(Q.P); pp["m"] = Q.P["m"] + m_extra
        Vk, Ax, _, _ = hybrid_ggv(ratio=None, p=pp)
        _, Ay, Ab, _ = Q.ggv_limits(p=pp)
        lap = Q.simulate_lap(tr, Vk, Ay, Ab, Ax, p=pp)
        print(f"  {pp['m']:>13.0f}{lap['t']:>15.2f}{lap['t']-lap0['t']:>+12.2f}")
    print("  注：上表只反映动力学影响；电池包质量必须计入（见下方重量估算）")

    print("\n【9】★ 电池约束下的真实前驱能力（15S1P × 60Ah 方形 LFP）")
    NS, CAP, R_CELL, VOC_CELL = 15, 60.0, 0.002, 3.31
    VOC = NS * VOC_CELL
    R_PACK = NS * R_CELL
    I_CONT, I_PULSE = 3.0 * CAP, 5.0 * CAP          # 3C 持续 / 5C 脉冲(<10s)
    print(f"  电芯 MB-LFP-32173128：3.2V/60Ah/192Wh，内阻≤2mΩ，3.0C持续/5C脉冲，1410g/只")
    print(f"  电池包 15S1P：Voc={VOC:.1f}V  R={R_PACK*1000:.0f}mΩ  "
          f"持续{I_CONT:.0f}A  脉冲{I_PULSE:.0f}A  重量(电芯){NS*1.41:.1f}kg")
    print(f"  {'电流[A]':>9}{'端电压[V]':>11}{'电功率[kW]':>12}   备注")
    for I in [100, 150, 180, 220, 260, 300]:
        V = VOC - I * R_PACK
        tag = "3C 持续上限" if abs(I - 180) < 1 else ("5C 脉冲上限" if abs(I - 300) < 1 else "")
        print(f"  {I:>9}{V:>11.2f}{V*I/1000:>12.2f}   {tag}")
    P_PULSE = (VOC - I_PULSE * R_PACK) * I_PULSE
    P_CONT = (VOC - I_CONT * R_PACK) * I_CONT
    print(f"  → 电池可提供：脉冲 {P_PULSE/1000:.1f} kW / 持续 {P_CONT/1000:.1f} kW")
    print(f"  → 远低于电机能力（2×17.8 kW）。前驱功率预算实际由【电池】封顶，")
    print(f"    且 300A 时端电压跌至 {VOC-I_PULSE*R_PACK:.1f} V（-{I_PULSE*R_PACK/VOC*100:.0f}%），")
    print(f"    这同时是 BMS 电压/电流采样与 SoC 估算必须面对的工况。")

    print("\n【10】综合结算：电池封顶 + 全部增重后的净收益")
    M_MOTOR = 2 * MOTOR[150]["mass"]
    M_ESC = 2 * ESC["mass"]
    M_DRIVE = 1.5                                  # 支架/减速机构/线束
    M_CELL = NS * 1.41
    M_BATT_EXTRA = 3.5                             # BMS + 外壳 + 高压线束
    M_ADD = M_MOTOR + M_ESC + M_DRIVE + M_CELL + M_BATT_EXTRA
    print(f"  增重明细：电机 {M_MOTOR:.1f} + 电调 {M_ESC:.1f} + 传动 {M_DRIVE:.1f} "
          f"+ 电芯 {M_CELL:.1f} + BMS/壳/线 {M_BATT_EXTRA:.1f} = {M_ADD:.1f} kg")
    print(f"  整车 {Q.P['m']:.0f} → {Q.P['m']+M_ADD:.0f} kg（+{M_ADD/Q.P['m']*100:.1f}%）")
    pp = dict(Q.P); pp["m"] = Q.P["m"] + M_ADD
    Vk, Ax, Ff, Ib = hybrid_ggv(ratio=5, kv=150, p=pp, p_budget=P_PULSE)
    _, Ay, Ab, _ = Q.ggv_limits(p=pp)
    lap_h = Q.simulate_lap(tr, Vk, Ay, Ab, Ax, p=pp)
    ta_h, _ = accel_event(75.0, ratio=5, kv=150, p=pp, p_budget=P_PULSE)
    print(f"  {'':>22}{'圈速[s]':>10}{'75m加速[s]':>13}{'前轴力峰值[N]':>14}")
    print(f"  {'基准 240kg 纯后驱':>20}{lap0['t']:>10.2f}{t0:>13.3f}{0:>14.0f}")
    print(f"  {'方案 含全增重':>22}{lap_h['t']:>10.2f}{ta_h:>13.3f}{np.max(Ff):>14.0f}")
    print(f"  {'净变化':>22}{lap_h['t']-lap0['t']:>+10.2f}{ta_h-t0:>+13.3f}")
    print(f"  ※ 其中增重单独贡献约 {M_ADD/10*0.43:+.2f} s 圈速劣化")
    print(line)


if __name__ == "__main__":
    main()
