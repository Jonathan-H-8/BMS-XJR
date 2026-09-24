"""
整车牵引能量首算（First-cut Energy Estimate）
================================================
目的：在不动底盘组圈速模型的前提下，先算出"整车轮上牵引能量"的量级，
      为 48V 动力电池的容量选型提供第一版数量级判断。

方法：
  1. 用 qss_ref.py 复现底盘组的飞驰圈速度剖面 V(s)、Ax(s)
  2. 轮上牵引力 F(s) = m·Ax + 气动阻力 D + 滚动阻力 R
     （原圈速模型未含滚动阻力，此处显式补上）
  3. 轮上功率 P(s) = F(s)·V(s)，对时间积分得单圈能量
  4. 按耐久赛 22 km 折算总能量

关键前提（可调）：
  - Crr 滚动阻力系数：取 0.015（FSAE 干地铺装赛道典型值，需实测标定）
  - 本首算给出的是"整车总牵引能量"，不是"电池能量"。
    电池实际负担 = 总牵引能量 × 前驱电机出力占比 ÷ 电驱效率
"""

import numpy as np
import qss_ref as Q

# ---------------------------------------------------------- 可调参数
CRR = 0.015          # 滚动阻力系数 [-]
ENDURANCE_KM = 22.0  # 耐久赛里程 [km]
REGEN_EFF = 0.60     # 制动能量回收效率（电机+控制器+电池总效率）
DRIVE_EFF = 0.85     # 电驱系统总效率（电池→轮上）


def wheel_energy(lap, track, m=None, crr=CRR):
    """计算单圈轮上牵引能量与功率统计。"""
    p = dict(Q.P)
    if m:
        p.update(m)
    m = p["m"]

    s = lap["s"]
    v_kmh = lap["v"]
    ax = lap["ax"]
    vm = v_kmh / 3.6
    dt = lap["dt"]
    L = track["L"]

    # 气动阻力
    D = 0.5 * Q.RHO * p["CDA"] * vm ** 2
    # 滚动阻力（本模型原先缺失）
    R = crr * m * Q.G
    # 轮上牵引力 = 质量·加速度 + 阻力 + 滚阻
    F = m * ax + D + R

    # 半程平均速度用于功率积分（与圈速一致）
    v_half = 0.5 * (vm[:-1] + vm[1:])
    F_half = 0.5 * (F[:-1] + F[1:])

    P = F_half * v_half                 # 轮上瞬时功率 [W]
    E_pos = np.sum(np.clip(P, 0, None) * dt)      # 牵引（放电）能量 [J]
    E_neg = np.sum(np.clip(P, None, 0) * dt)      # 制动（可回收）能量 [J]

    return dict(
        F=F, P=P, dt=dt,
        E_pos=E_pos, E_neg=E_neg,
        E_net=E_pos + E_neg,
        P_max=np.max(P), P_min=np.min(P),
        t=lap["t"], L=L,
    )


if __name__ == "__main__":
    track_file = (
        r"E:\FSAE_XJRT\BMS\仿真\refs_chassis"
        r"\西安交通大学毅行赛车队底盘组matlab动力学程序"
        r"\GGV_LTS_SensitivityAnsysis_V4.0\2026_ChengDu.txt"
    )
    tr = Q.load_track(track_file)
    Vk, Ay, Ab, Ad = Q.ggv_limits()
    lap = Q.simulate_lap(tr, Vk, Ay, Ab, Ad)
    e = wheel_energy(lap, tr)

    J2KWH = 1 / 3.6e6          # J -> kWh
    laps = ENDURANCE_KM * 1000 / tr["L"]

    print("=" * 68)
    print("【单圈】轮上牵引能量")
    print("-" * 68)
    print(f"  圈速              : {e['t']:.2f} s      赛道长 {e['L']:.1f} m")
    print(f"  牵引(放电)能量    : {e['E_pos']*J2KWH*1000:8.1f} Wh   平均功率 {e['E_pos']/e['t']:.0f} W")
    print(f"  制动(可回收)能量  : {e['E_neg']*J2KWH*1000:8.1f} Wh")
    print(f"  净能量            : {e['E_net']*J2KWH*1000:8.1f} Wh")
    print(f"  回收能量占比      : {-e['E_neg']/e['E_pos']*100:5.1f} %")
    print(f"  轮上功率峰值      : {e['P_max']/1000:6.1f} kW  /  再生峰值 {e['P_min']/1000:.1f} kW")
    print(f"  平均车速          : {np.mean(lap['v']):.1f} km/h")

    print()
    print("=" * 68)
    print(f"【耐久赛】{ENDURANCE_KM:.0f} km  ≈  {laps:.1f} 圈")
    print("-" * 68)
    print(f"  总牵引能量        : {e['E_pos']*laps*J2KWH:8.2f} kWh")
    print(f"  总可回收能量      : {-e['E_neg']*laps*J2KWH:8.2f} kWh")
    print(f"  净能量(不减回收)  : {e['E_net']*laps*J2KWH:8.2f} kWh")
    print(f"  净能量(按{REGEN_EFF*100:.0f}%回收) : "
          f"{(e['E_pos']+e['E_neg']*REGEN_EFF)*laps*J2KWH:8.2f} kWh")
    print(f"  比赛总时长        : {e['t']*laps/60:.1f} min")

    print()
    print("=" * 68)
    print("【48V 动力电池侧】按前驱电机承担牵引力比例 λ 折算")
    print("-" * 68)
    print(f"  {'λ(前驱占比)':>11}{'放电能量':>12}{'回收能量':>12}{'净消耗':>12}{'峰值功率':>11}")
    for lam in [0.20, 0.30, 0.40, 0.50]:
        Edis = e["E_pos"] * lam / DRIVE_EFF * laps * J2KWH
        Ereg = -e["E_neg"] * lam * REGEN_EFF * laps * J2KWH
        Ppk = e["P_max"] * lam / DRIVE_EFF
        print(f"  {lam:>11.0%}{Edis:>10.2f}kWh{Ereg:>10.2f}kWh"
              f"{(Edis-Ereg):>10.2f}kWh{Ppk/1000:>9.1f}kW")
    print("=" * 68)

