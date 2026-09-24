# ===== Cell 1 =====
import numpy as np

# 惯量
m_uf = m_ur = 8 # 簧下质量
m_s = (180+60)/2 - m_uf - m_ur # 半车重减去簧下
r = 0.38 # Iyy = m*rkk^2

# 阻尼与刚度
c_wf = 1000 # 阻尼系数初始值，无需修改
c_wr = 1000


c_tr = c_tf = 400 # 43075 R20实测值
k_tr = k_tf = 115000 # 43075 R20, 12psi

k_wf = 217 * 175.12683699 # 磅 -> N/m，已经从弹簧刚度通过运动比换算成线刚度，前弹簧刚度
k_wr = 180 * 175.12683699 # 后弹簧刚度

# 重心位置
cg_x = 0.45 # 静态前轴荷比
l = 1.545 #轴距

# 计算
b = l*cg_x
a = l*(1-cg_x)

I_yy = m_s*r**2

# ===== Cell 2 =====
A = np.array([
    [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0],
    [
        -(k_wf + k_wr) / m_s,
        (a * k_wf - b * k_wr) / m_s,
        k_wf / m_s,
        k_wr / m_s,
        -(c_wf + c_wr) / m_s,
        (a * c_wf - b * c_wr) / m_s,
        c_wf / m_s,
        c_wr / m_s
    ],
    [
        (a * k_wf - b * k_wr) / I_yy,
        -(a**2 * k_wf + b**2 * k_wr) / I_yy,
        -a * k_wf / I_yy,
        b * k_wr / I_yy,
        (a * c_wf - b * c_wr) / I_yy,
        -(a**2 * c_wf + b**2 * c_wr) / I_yy,
        -a * c_wf / I_yy,
        b * c_wr / I_yy
    ],
    [
        k_wf / m_uf,
        -a * k_wf / m_uf,
        -(k_wf + k_tf) / m_uf,
        0.0,
        c_wf / m_uf,
        -a * c_wf / m_uf,
        -(c_wf + c_tf) / m_uf,
        0.0
    ],
    [
        k_wr / m_ur,
        b * k_wr / m_ur,
        0.0,
        -(k_wr + k_tr) / m_ur,
        c_wr / m_ur,
        b * c_wr / m_ur,
        0.0,
        -(c_wr + c_tr) / m_ur
    ]
])

# ===== Cell 3 =====

# 计算特征值
def get_modes(A_matrix):
    eigvals = np.linalg.eigvals(A_matrix)
    
    # 选取虚部>0的特征值代表每个模态
    pos_imag = eigvals[np.imag(eigvals) > 0]
    # 按虚部排序
    pos_imag = pos_imag[np.argsort(np.imag(pos_imag))]

    modes = []
    for lam in pos_imag:
        sigma = np.real(lam)
        omega_d = np.imag(lam)
        omega_n = np.sqrt(sigma**2 + omega_d**2)
        zeta = -sigma / omega_n
        freq_hz = omega_n / (2 * np.pi)
        modes.append((freq_hz, zeta))

    # 按固有频率升序排列
    modes.sort(key=lambda x: x[0])
    if len(modes) < 2:
        modes = [(1.0, 2.0), (1.0, 2.0)]  # 过阻尼保护
    return modes

# 基准点分析（同时识别hop模态）
all_modes = get_modes(A)
heave_mode = all_modes[0]
pitch_mode = all_modes[1]
hop_modes = all_modes[2:] if len(all_modes) > 2 else []

print("=" * 55)
print("  XJ_Racing 半车垂向模态分析（基准点 c_wf=c_wr=1000 Ns/m）")
print("=" * 55)
print(f"  {'Heave (垂移)':15s} {heave_mode[0]:5.1f} Hz,  zeta = {heave_mode[1]:.3f}")
print(f"  {'Pitch (俯仰)':15s} {pitch_mode[0]:5.1f} Hz,  zeta = {pitch_mode[1]:.3f}")
labels = ["前轮 hop", "后轮 hop"]
for i, m in enumerate(hop_modes[:2]):
    print(f"  {labels[i]:15s} {m[0]:5.1f} Hz,  zeta = {m[1]:.3f}")
print()

# ===== Cell 4 =====

# 阻尼扫参范围
damping_sweep = np.arange(500, 5100, 100)  # 500~5000 Ns/m, 步长100（46点）
n = len(damping_sweep)

heave_zeta = np.zeros((n, n))
pitch_zeta = np.zeros((n, n))

print(f"阻尼扫参 {n}x{n} = {n*n} 组...")

for i in range(n):
    c_wf = damping_sweep[i]
    for j in range(n):
        c_wr = damping_sweep[j]
        
        A = np.array([
            [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0],
            [-(k_wf+k_wr)/m_s, (a*k_wf-b*k_wr)/m_s, k_wf/m_s, k_wr/m_s,
             -(c_wf+c_wr)/m_s, (a*c_wf-b*c_wr)/m_s, c_wf/m_s, c_wr/m_s],
            [(a*k_wf-b*k_wr)/I_yy, -(a**2*k_wf+b**2*k_wr)/I_yy, -a*k_wf/I_yy, b*k_wr/I_yy,
             (a*c_wf-b*c_wr)/I_yy, -(a**2*c_wf+b**2*c_wr)/I_yy, -a*c_wf/I_yy, b*c_wr/I_yy],
            [k_wf/m_uf, -a*k_wf/m_uf, -(k_wf+k_tf)/m_uf, 0.0,
             c_wf/m_uf, -a*c_wf/m_uf, -(c_wf+c_tf)/m_uf, 0.0],
            [k_wr/m_ur, b*k_wr/m_ur, 0.0, -(k_wr+k_tr)/m_ur,
             c_wr/m_ur, b*c_wr/m_ur, 0.0, -(c_wr+c_tr)/m_ur]
        ])
        
        modes = get_modes(A)
        heave_zeta[i][j] = modes[0][1]
        pitch_zeta[i][j] = modes[1][1]

# 找最优
h_best = np.unravel_index(np.argmax(heave_zeta), heave_zeta.shape)
p_best = np.unravel_index(np.argmax(pitch_zeta), pitch_zeta.shape)

print(f"\n  Heave zeta max = {heave_zeta[h_best]:.3f}  @ c_wf={damping_sweep[h_best[0]]:.0f}, c_wr={damping_sweep[h_best[1]]:.0f} Ns/m")
print(f"  Pitch zeta max = {pitch_zeta[p_best]:.3f}  @ c_wf={damping_sweep[p_best[0]]:.0f}, c_wr={damping_sweep[p_best[1]]:.0f} Ns/m")

# ================================================================
# 可视化
# ================================================================
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# 中文字体
plt.rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams.update({'font.size': 11, 'axes.titlesize': 13, 'axes.labelsize': 11})

fig, axes = plt.subplots(1, 2, figsize=(14, 5.8))
X, Y = np.meshgrid(damping_sweep, damping_sweep)

# ---- Heave ----
h_max = np.ceil(heave_zeta.max() * 20) / 20  # 上限取数据最大值向上取整
levels = np.linspace(0, h_max, 20)
cf1 = axes[0].contourf(X, Y, heave_zeta.T, levels=levels, cmap='RdYlBu_r', extend='both')
h_f = damping_sweep[h_best[0]]; h_r = damping_sweep[h_best[1]]
axes[0].scatter([h_f], [h_r],
                marker='*', s=250, c='gold', edgecolors='black', linewidths=1.2, zorder=5)
axes[0].annotate(f'F={h_f:.0f}, R={h_r:.0f}\nzeta={heave_zeta[h_best]:.3f}',
                xy=(h_f, h_r), xytext=(h_f+400, h_r-400),
                fontsize=9, fontweight='bold', color='darkred',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.85, edgecolor='gray'),
                arrowprops=dict(arrowstyle='->', color='gray', lw=1.2))
axes[0].set_xlabel('Front Damping [Ns/m]')
axes[0].set_ylabel('Rear Damping [Ns/m]')
axes[0].set_title(f'Heave Zeta  (max = {heave_zeta[h_best]:.3f})')
axes[0].grid(True, alpha=0.3, linestyle=':')
cbar1 = plt.colorbar(cf1, ax=axes[0], label='zeta', shrink=0.85)

# ---- Pitch ----
p_max = np.ceil(pitch_zeta.max() * 20) / 20
levels = np.linspace(0, p_max, 20)
cf2 = axes[1].contourf(X, Y, pitch_zeta.T, levels=levels, cmap='RdYlBu_r', extend='both')
p_f = damping_sweep[p_best[0]]; p_r = damping_sweep[p_best[1]]
axes[1].scatter([p_f], [p_r],
                marker='*', s=250, c='gold', edgecolors='black', linewidths=1.2, zorder=5)
axes[1].annotate(f'F={p_f:.0f}, R={p_r:.0f}\nzeta={pitch_zeta[p_best]:.3f}',
                xy=(p_f, p_r), xytext=(p_f+400, p_r-400),
                fontsize=9, fontweight='bold', color='darkred',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.85, edgecolor='gray'),
                arrowprops=dict(arrowstyle='->', color='gray', lw=1.2))
axes[1].set_xlabel('Front Damping [Ns/m]')
axes[1].set_ylabel('Rear Damping [Ns/m]')
axes[1].set_title(f'Pitch Zeta  (max = {pitch_zeta[p_best]:.3f})')
axes[1].grid(True, alpha=0.3, linestyle=':')
cbar2 = plt.colorbar(cf2, ax=axes[1], label='zeta', shrink=0.85)

# 总标题
param_text = (f"m_s={m_s:.0f}kg | k_wf={k_wf/1000:.1f} k_wr={k_wr/1000:.1f} N/mm | "
              f"k_t={k_tf/1000:.0f}N/mm | a={a:.2f} b={b:.2f}m | Iyy={I_yy:.1f}")
fig.suptitle(f'XJ_Racing 半车垂向模态阻尼扫参\n{param_text}',
             fontsize=12, fontweight='bold', y=0.98)
plt.subplots_adjust(top=0.85)

# 保存
outpath = r'D:\OH-WorkSpace\FSC-Vehicle-Dynamics-Tour\XJ_Racing_damping_sweep.png'
plt.savefig(outpath, dpi=180, bbox_inches='tight', facecolor='white', pad_inches=0.3)
print(f"\n图片已保存: {outpath}")
plt.show()
