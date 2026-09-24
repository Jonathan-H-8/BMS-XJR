"""
准稳态圈速仿真（QSS）参考实现 —— Python 版
================================================
用途：把底盘组 MATLAB 程序 GGV_Laptime_SensitivityAnsysis_GUI.m 的物理内核
      1:1 移植到 Python，用于：
        (1) 快速验证物理模型是否合理（机理先行）
        (2) 为后续 Simulink 模型提供"金标准"对照
        (3) 快速试算"前驱轮边电机"接入后的效果，避免反复开 MATLAB

物理链路：
    赛道曲率 k(s) -> 弯道限速 V_corner
    -> 前向加速 / 后向制动 双向积分 -> V(s) 飞驰圈速度剖面
    -> Ax(s), Ay(s), t_lap

作者备注：本文件不改动原 MATLAB 逻辑，只做等价移植 + 少量工程标注。
"""

import numpy as np

# ---------------------------------------------------------------- 车辆参数
P = dict(
    m=240.0,          # 整车质量 [kg]  含车手
    L=1.545,          # 轴距 [m]
    cog_f=0.55,       # 后轴静载荷比 [-]
    track=1.21,       # 轮距 [m]
    h=0.30,           # 质心高度 [m]
    CLA=4.0,          # 升力系数×迎风面积 [m^2]
    CDA=1.33,         # 风阻系数×迎风面积 [m^2]
    aeroDistF=0.40,   # 前轴下压力分配 [-]
    mu_x0=2.6,        # 纵向轮胎摩擦系数基准
    mu_y0=2.5,        # 横向轮胎摩擦系数基准
    k_mu_x=-0.0003,   # 纵向载荷敏感度 [1/N]
    k_mu_y=-0.0003,   # 横向载荷敏感度 [1/N]
    kx=0.65,          # 纵向修正系数
    ky=0.65,          # 横向修正系数
    brake_balance=0.65,   # 前制动比 [-]
    power_max=37000.0,    # 发动机最大功率 [W]
    V_max_kmh=120.0,      # 最高车速 [km/h]
    roll_k_f=0.5,         # 前侧倾刚度占比 [-]
    roll_k_r=0.5,
    # 悬架（仅用于车身姿态，不参与圈速）
    rc_f=0.030, rc_r=0.060, kw_f=38200.0, kw_r=31700.0,
    kroll_f=488.0 * 180 / np.pi, kroll_r=488.0 * 180 / np.pi,
)

G = 9.81
RHO = 1.225

# ---------- 车轮转动惯量修正（Hoosier 43075 16x7.5-10）----------
IW = 0.16      # 单轮转动惯量 [kg·m²]（轮胎+轮辋+刹车盘）
R_EFF = 0.204  # 有效滚动半径 [m]（自由半径 0.2057 m）


# ---------------------------------------------------------------- 赛道读取
def load_track(filename):
    """读取 Creo 曲率分析导出文件，取第 2/3 列作为 X/Y，重算曲率与里程。"""
    rows = []
    with open(filename, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.split()
            nums = []
            for tok in parts:
                try:
                    nums.append(float(tok))
                except ValueError:
                    break          # 遇到非数字即刻停止（模拟 sscanf '%f' 行为）
            if len(nums) >= 5:
                rows.append(nums[:6])
    d = np.array(rows)
    x, y = d[:, 1], d[:, 2]
    ds = np.hypot(np.diff(x), np.diff(y))
    s = np.concatenate(([0.0], np.cumsum(ds)))
    dx_ds = np.gradient(x, s)
    dy_ds = np.gradient(y, s)
    d2x = np.gradient(dx_ds, s)
    d2y = np.gradient(dy_ds, s)
    curv = (dx_ds * d2y - dy_ds * d2x) / np.power(dx_ds ** 2 + dy_ds ** 2, 1.5)
    return dict(x=x, y=y, s=s, curv=curv, L=s[-1])


# ---------------------------------------------------------------- GGV 包络
def ggv_limits(p=None):
    """按车速扫描，求纵向驱动/制动极限与横向极限（四轮载荷转移迭代）。"""
    q = dict(P)
    if p:
        q.update(p)

    m, L = q["m"], q["L"]
    a = q["cog_f"] * L
    b = L - a
    tf = tr = q["track"]
    h = q["h"]
    m_eff = m + 4 * IW / R_EFF ** 2          # 含四轮旋转惯量

    def mu_x(Fz):
        return q["kx"] * np.maximum(0.0, q["mu_x0"] + q["k_mu_x"] * np.asarray(Fz))

    def mu_y(Fz):
        return q["ky"] * np.maximum(0.0, q["mu_y0"] + q["k_mu_y"] * np.asarray(Fz))

    V_kmh = np.linspace(0.5, q["V_max_kmh"], 25)
    V = V_kmh / 3.6
    n = len(V)

    Ay = np.zeros(n)
    Ax_b = np.zeros(n)
    Ax_d = np.zeros(n)

    for i in range(n):
        D = 0.5 * RHO * q["CDA"] * V[i] ** 2
        Fz_af = 0.5 * RHO * q["CLA"] * V[i] ** 2 * q["aeroDistF"]
        Fz_ar = 0.5 * RHO * q["CLA"] * V[i] ** 2 * (1 - q["aeroDistF"])
        Fz0_f = m * G * (b / L) + Fz_af
        Fz0_r = m * G * (a / L) + Fz_ar

        # --- 横向极限 ---
        ay = G
        for _ in range(30):
            dFz = m * ay * h / ((tf + tr) / 2)
            Fz = np.array([
                Fz0_f / 2 + q["roll_k_f"] * dFz,
                Fz0_f / 2 - q["roll_k_f"] * dFz,
                Fz0_r / 2 + q["roll_k_r"] * dFz,
                Fz0_r / 2 - q["roll_k_r"] * dFz,
            ])
            Fz = np.clip(Fz, 0, None)
            ay_new = np.sum(mu_y(Fz) * Fz) / m
            if abs(ay_new - ay) < 1e-5:
                break
            ay = ay_new
        Ay[i] = ay

        # --- 制动极限 ---
        ax = -G
        for _ in range(30):
            dFz = m * ax * h / L
            Fz_f = (Fz0_f - dFz) / 2
            Fz_r = (Fz0_r + dFz) / 2
            C_f = 2 * mu_x(max(Fz_f, 0)) * max(Fz_f, 0)
            C_r = 2 * mu_x(max(Fz_r, 0)) * max(Fz_r, 0)
            Fb = max(-C_f / q["brake_balance"], -C_r / (1 - q["brake_balance"]))
            ax_new = (Fb - D) / m_eff
            if abs(ax_new - ax) < 1e-5:
                break
            ax = ax_new
        Ax_b[i] = ax

        # --- 驱动极限（★ 原程序假定后驱，只有发动机）---
        ax = 5.0
        for _ in range(30):
            dFz = m * ax * h / L
            Fz_rl = max(0.0, (Fz0_r + dFz) / 2)
            Fz_rr = max(0.0, (Fz0_r + dFz) / 2)
            Fx_rear = 2 * min(mu_x(Fz_rl) * Fz_rl, mu_x(Fz_rr) * Fz_rr)
            Fx_limit = min(Fx_rear, q["power_max"] / V[i])
            ax_new = (Fx_limit - D) / m_eff
            if abs(ax_new - ax) < 1e-5:
                break
            ax = ax_new
        Ax_d[i] = ax

    return V_kmh, Ay, Ax_b, Ax_d


# ---------------------------------------------------------------- 圈速仿真
def simulate_lap(track, V_kmh, Ay_max, Ax_brk, Ax_drv, p=None):
    q = dict(P)
    if p:
        q.update(p)

    s_orig = track["s"]
    curv_orig = track["curv"]
    L = track["L"]

    # 赛道首尾拼接三份，取中间一份作为"飞驰圈"，消除起终点加速段影响
    curv = np.concatenate([curv_orig[:-1], curv_orig[:-1], curv_orig])
    ds_orig = np.diff(s_orig)
    ds = np.concatenate([ds_orig, ds_orig, ds_orig])
    s = np.concatenate(([0.0], np.cumsum(ds)))
    n = len(s)

    fAy = lambda v: max(np.interp(v, V_kmh, Ay_max), 1e-4)
    fAd = lambda v: max(np.interp(v, V_kmh, Ax_drv), 0.0)
    fAb = lambda v: min(np.interp(v, V_kmh, Ax_brk), 0.0)

    # --- 1) 弯道限速（二分求解 V = sqrt(Ay_max(V)/k)）---
    V_cor = np.full(n, q["V_max_kmh"])
    for i in range(n):
        kap = abs(curv[i])
        if kap < 1e-6:
            continue
        lo, hi = 0.5, q["V_max_kmh"]
        f_lo = lo - 3.6 * np.sqrt(fAy(lo) / kap)
        f_hi = hi - 3.6 * np.sqrt(fAy(hi) / kap)
        if f_hi <= 0:
            continue
        if f_lo >= 0:
            V_cor[i] = 0.5
            continue
        for _ in range(50):
            mid = 0.5 * (lo + hi)
            f_mid = mid - 3.6 * np.sqrt(fAy(mid) / kap)
            if abs(f_mid) < 1e-4 or (hi - lo) < 0.01:
                break
            if f_mid > 0:
                hi = mid
            else:
                lo = mid
        V_cor[i] = 0.5 * (lo + hi)

    # --- 2) 前向加速 ---
    V_f = np.zeros(n)
    V_f[0] = 0.5
    for i in range(1, n):
        v = V_f[i - 1]
        dsv = s[i] - s[i - 1]
        ay_dem = (v / 3.6) ** 2 * abs(curv[i])
        ay_lim = max(fAy(v), 1e-4)
        if ay_dem >= ay_lim:
            ax_pos = 0.0
        else:
            ax_pos = max(fAd(v), 0.0) * np.sqrt(1 - (ay_dem / ay_lim) ** 2)
        v_new = np.sqrt(max(0.0, (v / 3.6) ** 2 + 2 * ax_pos * dsv)) * 3.6
        V_f[i] = min(max(0.5, v_new), V_cor[i])

    # --- 3) 后向制动 ---
    V_b = np.zeros(n)
    V_b[-1] = 0.5
    for i in range(n - 2, -1, -1):
        v = V_b[i + 1]
        dsv = s[i + 1] - s[i]
        ay_dem = (v / 3.6) ** 2 * abs(curv[i])
        ay_lim = max(fAy(v), 1e-4)
        if ay_dem >= ay_lim:
            ax_pos = 0.0
        else:
            ax_pos = min(fAb(v), 0.0) * np.sqrt(1 - (ay_dem / ay_lim) ** 2)
        v_new = np.sqrt(max(0.0, (v / 3.6) ** 2 - 2 * ax_pos * dsv)) * 3.6
        V_b[i] = min(max(0.5, v_new), V_f[i])

    # --- 4) 取中间一份 ---
    # MATLAB 为 1-based：idx_start = no, idx_end = 2*no-1
    # 等价 Python 0-based 切片：[no-1 : 2*no-1]
    no = len(s_orig)
    V_lap = V_b[no - 1: 2 * no - 1]
    s_lap = s[no - 1: 2 * no - 1] - L

    dt = np.diff(s_lap) / ((V_lap[:-1] + V_lap[1:]) / 2 / 3.6)
    t_lap = float(np.sum(dt))

    vm = V_lap / 3.6
    Ay_lap = vm ** 2 * curv_orig
    Ax_lap = np.zeros_like(V_lap)
    Ax_lap[1:-1] = 0.5 * (vm[2:] ** 2 - vm[:-2] ** 2) / (s_lap[2:] - s_lap[:-2])
    Ax_lap[0], Ax_lap[-1] = Ax_lap[1], Ax_lap[-2]

    return dict(s=s_lap, v=V_lap, ax=Ax_lap, ay=Ay_lap, t=t_lap, dt=dt)


# ---------------------------------------------------------------- 自检
if __name__ == "__main__":
    import sys

    track_file = sys.argv[1] if len(sys.argv) > 1 else (
        r"E:\FSAE_XJRT\BMS\仿真\refs_chassis"
        r"\西安交通大学毅行赛车队底盘组matlab动力学程序"
        r"\GGV_LTS_SensitivityAnsysis_V4.0\2026_ChengDu.txt"
    )

    tr = load_track(track_file)
    print("=" * 62)
    print("赛道：", track_file.split("\\")[-1])
    print(f"  采样点数      : {len(tr['s'])}")
    print(f"  赛道总长      : {tr['L']:.1f} m")
    k = np.abs(tr["curv"])
    print(f"  最小转弯半径  : {1/max(k):.1f} m  (最大曲率 {max(k):.4f} 1/m)")
    print(f"  曲率 95 分位  : {np.percentile(k,95):.4f} 1/m  -> R={1/np.percentile(k,95):.1f} m")

    Vk, Ay, Ab, Ad = ggv_limits()
    print("-" * 62)
    print("GGV 包络（抽点）：")
    print(f"{'V[km/h]':>9}{'Ay_max[g]':>12}{'Ax_brake[g]':>13}{'Ax_drive[g]':>13}")
    for i in range(0, 25, 4):
        print(f"{Vk[i]:9.1f}{Ay[i]/G:12.2f}{Ab[i]/G:13.2f}{Ad[i]/G:13.2f}")
    print(f"  最大驱动加速度: {np.max(Ad)/G:.2f} g  @ {Vk[np.argmax(Ad)]:.0f} km/h")
    print(f"  最大制动减速度: {np.min(Ab)/G:.2f} g")

    lap = simulate_lap(tr, Vk, Ay, Ab, Ad)
    print("-" * 62)
    print(f"  飞驰圈圈速  : {lap['t']:.3f} s")
    print(f"  平均车速    : {np.mean(lap['v']):.1f} km/h")
    print(f"  最高车速    : {np.max(lap['v']):.1f} km/h")
    print(f"  纵向加速度峰值: +{np.max(lap['ax'])/G:.2f} g / {np.min(lap['ax'])/G:.2f} g")
    print(f"  横向加速度峰值: {np.max(np.abs(lap['ay']))/G:.2f} g")
    print("=" * 62)
