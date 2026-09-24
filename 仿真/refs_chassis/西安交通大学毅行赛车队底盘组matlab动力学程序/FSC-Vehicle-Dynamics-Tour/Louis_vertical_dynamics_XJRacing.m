% ================================================================
% XJ_Racing 半车垂向动力学 — 阻尼扫参（MATLAB版）
% 基于 Louis Ye 的 FSC-Vehicle-Dynamics-Tour
% ================================================================
clear; close all; clc;

%% ===== Cell 1: 参数 =====

% --- 质量 ---
m_uf = 8;           % 前簧下质量 [kg]（单侧）
m_ur = 8;           % 后簧下质量 [kg]（单侧）
m_s  = (180+60)/2 - m_uf - m_ur;  % 半车簧上质量 [kg]
r    = 0.38;        % 俯仰回转半径 [m]

% --- 阻尼（初始值，扫参时覆盖）---
c_wf = 1000;        % 前避震阻尼 [Ns/m]
c_wr = 1000;        % 后避震阻尼 [Ns/m]

% --- 刚度 ---
c_tf = 400;         % 前轮胎阻尼 [Ns/m]（43075 R20 实测）
c_tr = 400;         % 后轮胎阻尼 [Ns/m]
k_tf = 115000;      % 前轮胎垂直刚度 [N/m]（43075 R20, 12psi）
k_tr = 115000;      % 后轮胎垂直刚度 [N/m]

k_wf = 217 * 175.12683699;   % 前 wheel rate [N/m]（已从弹簧刚度经运动比换算）
k_wr = 180 * 175.12683699;   % 后 wheel rate [N/m]

% --- 几何 ---
cg_x = 0.45;        % 前轴质量占比
l    = 1.545;       % 轴距 [m]

% --- 计算 ---
b = l * cg_x;       % 重心到后轴距离 [m]
a = l * (1 - cg_x); % 重心到前轴距离 [m]
I_yy = m_s * r^2;   % 俯仰转动惯量 [kg·m²]

fprintf('=========================================================\n');
fprintf('  XJ_Racing 半车垂向动力学参数\n');
fprintf('=========================================================\n');
fprintf('  m_s = %.0f kg,  m_uf/ur = %.0f kg\n', m_s, m_uf);
fprintf('  k_wf = %.1f N/mm,  k_wr = %.1f N/mm,  k_t = %.0f N/mm\n', ...
    k_wf/1000, k_wr/1000, k_tf/1000);
fprintf('  a = %.3f m,  b = %.3f m,  I_yy = %.1f kg·m²\n', a, b, I_yy);
fprintf('\n');

%% ===== Cell 2: 构建 A 矩阵 =====

% 状态向量 x = [zs; theta; z_uf; z_ur; zs_dot; theta_dot; zuf_dot; zur_dot]

A = [ ...
    0, 0, 0, 0,   1, 0, 0, 0;
    0, 0, 0, 0,   0, 1, 0, 0;
    0, 0, 0, 0,   0, 0, 1, 0;
    0, 0, 0, 0,   0, 0, 0, 1;
    ...
    -(k_wf+k_wr)/m_s,  (a*k_wf-b*k_wr)/m_s,  k_wf/m_s,  k_wr/m_s, ...
    -(c_wf+c_wr)/m_s,  (a*c_wf-b*c_wr)/m_s,  c_wf/m_s,  c_wr/m_s;
    ...
    (a*k_wf-b*k_wr)/I_yy,  -(a^2*k_wf+b^2*k_wr)/I_yy,  -a*k_wf/I_yy,  b*k_wr/I_yy, ...
    (a*c_wf-b*c_wr)/I_yy,  -(a^2*c_wf+b^2*c_wr)/I_yy,  -a*c_wf/I_yy,  b*c_wr/I_yy;
    ...
    k_wf/m_uf,  -a*k_wf/m_uf,  -(k_wf+k_tf)/m_uf,  0, ...
    c_wf/m_uf,  -a*c_wf/m_uf,  -(c_wf+c_tf)/m_uf,  0;
    ...
    k_wr/m_ur,   b*k_wr/m_ur,  0,  -(k_wr+k_tr)/m_ur, ...
    c_wr/m_ur,   b*c_wr/m_ur,  0,  -(c_wr+c_tr)/m_ur  ...
    ];

%% ===== Cell 3: 模态分析 =====

% 基准点分析
all_modes = get_modes(A);
heave_mode = all_modes(1, :);
pitch_mode = all_modes(2, :);

fprintf('=========================================================\n');
fprintf('  XJ_Racing 半车垂向模态分析（c_wf=c_wr=1000 Ns/m）\n');
fprintf('=========================================================\n');
fprintf('  Heave (垂移)      %5.1f Hz,  zeta = %.3f\n', heave_mode(1), heave_mode(2));
fprintf('  Pitch (俯仰)      %5.1f Hz,  zeta = %.3f\n', pitch_mode(1), pitch_mode(2));
if size(all_modes, 1) >= 3
    fprintf('  前轮 hop          %5.1f Hz,  zeta = %.3f\n', all_modes(3,1), all_modes(3,2));
end
if size(all_modes, 1) >= 4
    fprintf('  后轮 hop          %5.1f Hz,  zeta = %.3f\n', all_modes(4,1), all_modes(4,2));
end
fprintf('\n');

%% ===== Cell 4: 阻尼扫参 =====

damping_sweep = 500:100:5000;   % 500~5000 Ns/m, 步长 100（46点）
n = length(damping_sweep);

heave_zeta = zeros(n, n);
pitch_zeta = zeros(n, n);

fprintf('阻尼扫参 %dx%d = %d 组...\n', n, n, n*n);

for i = 1:n
    for j = 1:n
        cf = damping_sweep(i);
        cr = damping_sweep(j);
        
        % 重建 A 矩阵（阻尼更新）
        A_scan = [ ...
            0, 0, 0, 0,   1, 0, 0, 0;
            0, 0, 0, 0,   0, 1, 0, 0;
            0, 0, 0, 0,   0, 0, 1, 0;
            0, 0, 0, 0,   0, 0, 0, 1;
            ...
            -(k_wf+k_wr)/m_s,  (a*k_wf-b*k_wr)/m_s,  k_wf/m_s,  k_wr/m_s, ...
            -(cf+cr)/m_s,  (a*cf-b*cr)/m_s,  cf/m_s,  cr/m_s;
            ...
            (a*k_wf-b*k_wr)/I_yy,  -(a^2*k_wf+b^2*k_wr)/I_yy,  -a*k_wf/I_yy,  b*k_wr/I_yy, ...
            (a*cf-b*cr)/I_yy,  -(a^2*cf+b^2*cr)/I_yy,  -a*cf/I_yy,  b*cr/I_yy;
            ...
            k_wf/m_uf,  -a*k_wf/m_uf,  -(k_wf+k_tf)/m_uf,  0, ...
            cf/m_uf,  -a*cf/m_uf,  -(cf+c_tf)/m_uf,  0;
            ...
            k_wr/m_ur,   b*k_wr/m_ur,  0,  -(k_wr+k_tr)/m_ur, ...
            cr/m_ur,   b*cr/m_ur,  0,  -(cr+c_tr)/m_ur  ...
            ];
        
        modes = get_modes(A_scan);
        heave_zeta(i,j) = modes(1, 2);
        pitch_zeta(i,j) = modes(2, 2);
    end
end

% 找最优
[h_max, h_idx] = max(heave_zeta(:));
[p_max, p_idx] = max(pitch_zeta(:));
[h_i, h_j] = ind2sub([n, n], h_idx);
[p_i, p_j] = ind2sub([n, n], p_idx);

fprintf('\n  Heave zeta max = %.3f  @ c_wf=%.0f, c_wr=%.0f Ns/m\n', ...
    h_max, damping_sweep(h_i), damping_sweep(h_j));
fprintf('  Pitch zeta max = %.3f  @ c_wf=%.0f, c_wr=%.0f Ns/m\n', ...
    p_max, damping_sweep(p_i), damping_sweep(p_j));

%% ===== 可视化 =====

[X, Y] = meshgrid(damping_sweep, damping_sweep);

figure('Position', [100, 100, 1200, 500]);

% ---- Heave ----
subplot(1, 2, 1);
h_levels = linspace(0, ceil(h_max*20)/20, 25);
contourf(X, Y, heave_zeta', h_levels, 'LineColor', 'none');
hold on;
plot(damping_sweep(h_i), damping_sweep(h_j), 'p', ...
    'MarkerSize', 18, 'MarkerFaceColor', 'yellow', ...
    'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
% 标注
text(damping_sweep(h_i)+300, damping_sweep(h_j)-350, ...
    sprintf('F=%.0f, R=%.0f\nzeta=%.3f', damping_sweep(h_i), damping_sweep(h_j), h_max), ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.6 0 0], ...
    'BackgroundColor', 'white', 'EdgeColor', [0.5 0.5 0.5]);
xlabel('Front Damping [Ns/m]');
ylabel('Rear Damping [Ns/m]');
title(sprintf('Heave Zeta  (max = %.3f)', h_max));
grid on; grid minor;  %#ok<*AGROW>
colormap(flipud(jet));
c1 = colorbar; c1.Label.String = 'zeta';
axis tight;

% ---- Pitch ----
subplot(1, 2, 2);
p_levels = linspace(0, ceil(p_max*20)/20, 25);
contourf(X, Y, pitch_zeta', p_levels, 'LineColor', 'none');
hold on;
plot(damping_sweep(p_i), damping_sweep(p_j), 'p', ...
    'MarkerSize', 18, 'MarkerFaceColor', 'yellow', ...
    'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
text(damping_sweep(p_i)+300, damping_sweep(p_j)-350, ...
    sprintf('F=%.0f, R=%.0f\nzeta=%.3f', damping_sweep(p_i), damping_sweep(p_j), p_max), ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.6 0 0], ...
    'BackgroundColor', 'white', 'EdgeColor', [0.5 0.5 0.5]);
xlabel('Front Damping [Ns/m]');
ylabel('Rear Damping [Ns/m]');
title(sprintf('Pitch Zeta  (max = %.3f)', p_max));
grid on; grid minor;
colormap(flipud(jet));
c2 = colorbar; c2.Label.String = 'zeta';
axis tight;

% 总标题
sgtitle({'\bf XJ\_Racing 半车垂向模态阻尼扫参'; ...
    sprintf('m_s=%.0fkg | k_{wf}=%.1f k_{wr}=%.1f N/mm | k_t=%.0fN/mm | a=%.2f b=%.2fm | I_{yy}=%.1f', ...
    m_s, k_wf/1000, k_wr/1000, k_tf/1000, a, b, I_yy)}, ...
    'FontSize', 11);

% 保存
saveas(gcf, 'XJ_Racing_damping_sweep_matlab.png');
fprintf('\n图片已保存: XJ_Racing_damping_sweep_matlab.png\n');

%% ===== 子函数 =====

function modes = get_modes(A_matrix)
    % 计算特征值，返回模态的 [频率(Hz), 阻尼比]
    % modes 按固有频率升序排列
    eigvals = eig(A_matrix);
    
    % 选取虚部 > 0 的特征值（振荡模态）
    pos_mask = imag(eigvals) > 1e-8;
    pos_imag = eigvals(pos_mask);
    
    % 按虚部（频率）升序排列
    [~, sort_idx] = sort(imag(pos_imag));
    pos_imag = pos_imag(sort_idx);
    
    modes_list = [];
    for k = 1:length(pos_imag)
        lam = pos_imag(k);
        sigma = real(lam);
        omega_d = imag(lam);
        omega_n = sqrt(sigma^2 + omega_d^2);
        zeta = -sigma / omega_n;
        freq_hz = omega_n / (2 * pi);
        modes_list = [modes_list; freq_hz, zeta];  %#ok<AGROW>
    end
    
    % 按固有频率升序排列
    if ~isempty(modes_list)
        [~, freq_idx] = sort(modes_list(:, 1));
        modes_list = modes_list(freq_idx, :);
    end
    
    % 过阻尼保护（模态数 < 2 时补占位值）
    if size(modes_list, 1) < 2
        modes_list = [1.0, 2.0; 1.0, 2.0];
    end
    
    modes = modes_list;
end
