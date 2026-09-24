%% vehParams.m —— XR27 混动整车电量仿真 · 统一参数脚本（S2 交付物）
%  =========================================================================
%  用途：把整车 / 电机 / 电调 / 电池 / 传动 / 策略参数集中到一处，
%        Simulink 模型用 Model Callback 的 InitFcn 调用本脚本，
%        所有模块从 base workspace 读变量。
%
%  数据来源与可信度标注：
%        [底盘组]  来自"西安交通大学毅行赛车队底盘组 matlab 动力学程序"
%                  GGV_Laptime_SensitivityAnsysis_GUI.m（已用 qss_ref.py 复现验证）
%        [规格书]  来自厂家 datasheet（PDF，已逐项核对）
%        [待确认]  ★ 必须补齐或台架标定的量，当前为占位/估算值
%
%  最近更新：2026-09-24
%  =========================================================================

clear; clc;

%% ---------------------------------------------------------------- 1. 整车
% [底盘组] GGV GUI 默认值
veh.m        = 240;          % 整车质量（含车手）[kg]
veh.L        = 1.545;        % 轴距 [m]
veh.cog_f    = 0.55;         % 后轴静载荷比 [-]
veh.track    = 1.21;         % 轮距 [m]
veh.h        = 0.30;         % 质心高度 [m]
veh.CLA      = 4.0;          % 升力系数 × 迎风面积 [m^2]
veh.CDA      = 1.33;         % 风阻系数 × 迎风面积 [m^2]
veh.aeroDistF= 0.40;         % 前轴下压力分配比 [-]
veh.mu_x0    = 2.6;          % 纵向轮胎摩擦系数基准
veh.mu_y0    = 2.5;
veh.k_mu_x   = -0.0003;      % 纵向载荷敏感度 [1/N]
veh.k_mu_y   = -0.0003;
veh.kx       = 0.65;         % Pacejka 修正系数（纵）
veh.ky       = 0.65;         % Pacejka 修正系数（横）
veh.brake_balance = 0.65;    % 前制动比 [-]
veh.V_max_kmh= 120;          % 最高车速限 [km/h]
veh.roll_k_f = 0.5;  veh.roll_k_r = 0.5;

% [底盘组] 车轮
veh.r_eff    = 0.204;        % 有效滚动半径 [m]（自由半径 0.2057）
veh.Iw       = 0.16;         % 单轮转动惯量 [kg·m^2]
veh.tire     = 'Hoosier 43075 16x7.5-10';

% [待确认] ★ 滚动阻力系数——底盘组 GGV 程序未建模滚阻，需实测或文献取值
veh.crr      = 0.015;        % 建议范围 0.012~0.018

% [待确认] ★ 发动机参数（当前只有功率）
pt.eng.P_max = 37000;        % [底盘组] 发动机最大功率 [W]
pt.eng.torque_map = [];      % 待补：转速-扭矩 MAP

%% ---------------------------------------------------------------- 2. 赛道
trk.file     = '2026_ChengDu.txt';   % Creo 曲率导出（6250 点）
trk.length   = 898.4;                % [底盘组/已复现] 单圈长度 [m]
trk.R_min    = 5.8;                  % 最小转弯半径 [m]
% 赛事
evt.endurance_km = 22;               % [赛规核实] 耐久赛总里程 [km]
evt.accel_dist   = 75;               % 直线加速距离 [m]
evt.laps     = evt.endurance_km*1000/trk.length;   % ≈ 24.5 圈
% [待确认] ★ 耐久赛是否允许中途换电池（影响单包容量设计）
evt.battery_swap_allowed = true;

%% ---------------------------------------------------------------- 3. 电机
% [规格书] Maytech MTI120116 系列（3194560061MTI120116-HA-SF 中文规格）
% 型号命名：HA = 带霍尔(Sensored)，SF = 水冷(Water-cooled)，KV 未编入型号！
% ★★★ 待确认：实际订购的是哪一档 KV？（官网标准款只有 100KV / 150KV）
mtr.name = 'Maytech MTI120116-HA-SF';
mtr.construction = '12N10P';        % 12 槽 10 极 → 5 对极
mtr.pole_pairs   = 5;
mtr.rpm_max      = 9000;            % 机械最高转速
mtr.T_max_temp   = 120;             % [℃]
mtr.count        = 2;               % 前驱轮边电机台数（左右各一）

% 全系列参数表：行 = [KV, Kt(N·m/A), Vmax(V), I_max(A), P_max(W), T_max@60%(N·m), ...
%                     T_rated@80%(N·m), eta_max, mass(kg)]
mtr.table = [ ...
%   KV      Kt      Vmax  Imax  Pmax   Tmax   Trated etaMax mass
    275,  0.0392,   32,   480, 15300, 18.8,  12.8,  0.89, 4.1; ...
    230,  0.0475,   39,   430, 17500, 20.3,  13.5,  0.87, 4.2; ...
    200,  0.0547,   52,   380, 15000, 20.6,  13.6,  0.90, 4.4; ...
    173,  0.0612,   52,   340, 17500, 20.8,  13.8,  0.91, 4.3; ...
    150,  0.0692,   60,   300, 17800, 21.8,  14.3,  0.91, 4.2; ...
    100,  0.0794,   90,   220, 18800, 22.6,  14.7,  0.88, 4.5];

mtr.KV       = 150;                 % ★★★ 待确认（150 或 100）
idx = mtr.table(:,1) == mtr.KV;
mtr.Kt       = mtr.table(idx,2);    % [N·m/A]
mtr.V_max    = mtr.table(idx,3);    % 最大输入电压 [V]
mtr.I_max    = mtr.table(idx,4);    % 最大工作电流（峰值）[A]
mtr.P_max    = mtr.table(idx,5);    % 最大输出功率 [W]
mtr.T_max    = mtr.table(idx,6);    % 最大扭矩 @60% 效率 [N·m]
mtr.T_rated  = mtr.table(idx,7);    % 额定扭矩 @80% 效率 [N·m]
mtr.eta_max  = mtr.table(idx,8);
mtr.mass     = mtr.table(idx,9);    % 单台质量 [kg]

% [待确认] ★★★ 规格书只给"最高效率"单点，没有效率 MAP。
%   当前用常数效率占位；正式模型需要用台架数据或解析损耗模型替换。
mtr.eta_const = 0.88;               % 电机 + 电调综合效率（占位）
mtr.R_eq      = 0.030;              % DC 等效内阻 [Ω]，仅用于"电压—转速"约束估算
% 参考：厂家网页给 200KV 版内阻 0.0322Ω；按 Kt^2 缩放到 150KV 约 0.05Ω

%% ---------------------------------------------------------------- 4. 电调
% [规格书] Makerbase MKSESC 75200 V2（VESC 架构）
esc.name        = 'MKSESC 75200 V2 (VESC)';
esc.V_min       = 14;               % 输入电压下限 [V]
esc.V_max       = 84;               % 输入电压上限 [V]
esc.I_cont_50V  = 200;              % 50V 时持续电流 [A]
esc.I_cont_75V  = 150;              % 75V 时持续电流 [A]
esc.I_pulse     = 300;              % 最大脉冲电流 [A]
esc.erpm_max    = 150000;           % 电调极限 ERPM
esc.MCU         = 'STM32F405RGT6';
esc.mass        = 0.35;             % [kg] 估算
esc.iface       = {'PPM','Analog','UART','I2C','USB','CAN'};  % 支持 CAN → 可与 BMS/VCU 互通
% ★ 选型未定：VESC 现成 vs 自研。见 README「电调选型」一节。

%% ---------------------------------------------------------------- 5. 电池
% [规格书] 候选电芯 A：MB-LFP-32173128 方形
cellA.name = 'MB-LFP-32173128';
cellA.V    = 3.2;      cellA.Cap = 60;     cellA.E = 192;      % [V, Ah, Wh]
cellA.R    = 0.002;    % 内阻 ≤2 mΩ
cellA.I_cont = 3.0;    % 持续放电倍率 [C]  → 180 A
cellA.I_pulse= 5.0;    % 脉冲放电倍率 [C]  (<10 s, SOC>20%) → 300 A
cellA.I_chg  = 2.0;    % 最大充电倍率 [C]
cellA.mass   = 1.410;  % [kg]

% [规格书] 候选电芯 B：MB-IFR26650 圆柱
cellB.name = 'MB-IFR26650';
cellB.V    = 3.2;      cellB.Cap = 3.8;    cellB.E = 12.16;
cellB.R    = 0.060;    % 内阻 ≤60 mΩ（偏高）
cellB.I_cont = 3.0;    cellB.I_pulse = 5.0;  cellB.I_chg = 1.0;
cellB.mass   = 0.092;

% [待确认] ★ 建议寻找高倍率(≥10C) LFP 电芯替换，理由见 README
% 当前方案：15S1P
batt.cell   = cellA;
batt.Ns     = 15;              % 串联数：3.2V × 15 = 48V 标称（满充 54.75V）
batt.Np     = 1;
batt.V_nom  = batt.cell.V * batt.Ns;                % 48.0 V
batt.V_max  = 3.65 * batt.Ns;                       % 54.75 V
batt.V_oc   = 3.31 * batt.Ns;                       % ≈49.6 V (50% SOC 附近)
batt.E_nom  = batt.cell.E * batt.Ns * batt.Np / 1000;   % 2.88 kWh
batt.R_pack = batt.cell.R * batt.Ns / batt.Np;      % 30 mΩ
batt.I_cont = batt.cell.I_cont  * batt.cell.Cap * batt.Np;  % 180 A
batt.I_pulse= batt.cell.I_pulse * batt.cell.Cap * batt.Np;  % 300 A
batt.mass_cell = batt.cell.mass * batt.Ns * batt.Np;        % 21.1 kg
batt.mass_extra= 3.5;          % BMS + 外壳 + 高压线束 [kg]
batt.mass   = batt.mass_cell + batt.mass_extra;

% 电池可用功率（Rint 模型）：P = (Voc - I·R)·I
batt.P_pulse = (batt.V_oc - batt.I_pulse*batt.R_pack)*batt.I_pulse;  % ≈12.2 kW
batt.P_cont  = (batt.V_oc - batt.I_cont *batt.R_pack)*batt.I_cont;   % ≈8.0 kW

%% ---------------------------------------------------------------- 6. 传动
% ★★★ 待确认：前驱传动方案与减速比（这是当前最关键的设计缺口）
% 需求：要达到 30% 助力比需要 i≈5；i=3 只有 21%，i=6 达 43%
drv.ratio    = 5.0;            % ★ 减速比（同步带/链传动假设）
drv.eta      = 0.95;           % 传动效率
drv.type     = 'belt/chain (待确认)';

%% ---------------------------------------------------------------- 7. 电驱策略
% ★★★ 待确认：S3/S4 要定的"电驱介入策略"
str.lambda_share = 0.35;       % 前驱承担的牵引力比例（稳态）
str.P_budget     = batt.P_pulse;   % 前驱电功率预算上限 [W]（默认由电池封顶）
str.regen_frac   = 0.50;       % 制动能量回收比例（含前轴附着力/电机/电池三重限制）

%% ---------------------------------------------------------------- 8. 派生量
% 含旋转惯量的等效质量
derived.m_eff = veh.m + 4*veh.Iw/veh.r_eff^2;
% 前驱系统总增重
derived.m_add = mtr.count*mtr.mass + 2*esc.mass + 1.5 + batt.mass;
% 参考：电机工况点
derived.axle_force_per_amp = mtr.Kt * drv.ratio * drv.eta * mtr.count ...
                             / veh.r_eff;    % [N/A] 相电流→轮上驱动力

fprintf('=== XR27 混动电量仿真参数已加载 ===\n');
fprintf('  整车 %.0f kg (+%.1f kg 混动系统)  |  电池 %.2f kWh / %.0fV\n', ...
        veh.m, derived.m_add, batt.E_nom, batt.V_nom);
fprintf('  电机 %s @ %dKV ×%d  传动比 %.1f  |  电池可用功率 脉冲 %.1f kW\n', ...
        mtr.name, mtr.KV, mtr.count, drv.ratio, batt.P_pulse/1000);
fprintf('  ★ 待确认项：mtr.KV / drv.ratio / mtr.eta_const / veh.crr\n');
