% 轮胎载荷分布分析
% 跑一圈圈速模拟，画出四轮载荷沿赛道的分布 + 直方图
% 炳森 | 2026-07-06

clear; clc;

% ---- 车辆参数（与GUI一致）----
m = 240; L = 1.545; cog_f = 0.55; track = 1.21;
h = 0.3; CLA = 4; CDA = 1.33; aeroDistF = 0.4;
mu_x0 = 2.6; mu_y0 = 2.5; k_mu_x = -0.0003; k_mu_y = -0.0003;
kx = 0.65; ky = 0.65; brake_balance = 0.65; power_max = 37000;
V_max_kmh = 120; roll_k_f = 0.5; roll_k_r = 0.5;
g = 9.81; rho = 1.225;
Iw = 0.16; r_eff = 0.204;
m_eff = m + 4*Iw/r_eff^2;

a = cog_f * L; b = L - a;
mu_func_y = @(Fz) ky * max(0, mu_y0 + k_mu_y * Fz);
mu_func_x = @(Fz) kx * max(0, mu_x0 + k_mu_x * Fz);

% ---- 读取赛道 ----
filename = '2026_ChengDu.txt';
fid = fopen(filename, 'r'); data = [];
while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line) || isempty(strtrim(line)), continue; end
    nums = sscanf(line, '%f');
    if length(nums) < 5, continue; end
    data = [data; nums'];
end
fclose(fid);
x = data(:,2); y = data(:,3);
dx = diff(x); dy = diff(y);
s = [0; cumsum(sqrt(dx.^2 + dy.^2))];
dx_ds = gradient(x, s); dy_ds = gradient(y, s);
d2x_ds2 = gradient(dx_ds, s); d2y_ds2 = gradient(dy_ds, s);
curv = (dx_ds.*d2y_ds2 - dy_ds.*d2x_ds2) ./ (dx_ds.^2 + dy_ds.^2).^(3/2);
L_track = s(end);

% ---- GGV极限 ----
V_kmh = linspace(0.5, V_max_kmh, 25)'; V_ms = V_kmh/3.6;
Ay_max = zeros(25,1); Ax_brake = zeros(25,1); Ax_drive = zeros(25,1);

for iV = 1:25
    V = V_ms(iV);
    D = 0.5*rho*CDA*V^2;
    Fz_aero = 0.5*rho*CLA*V^2;
    Fz_aero_f = Fz_aero*aeroDistF;
    Fz_aero_r = Fz_aero*(1-aeroDistF);
    
    Ay = 9.81;
    for iter = 1:30
        Fz0_f = m*g*(b/L)+Fz_aero_f; Fz0_r = m*g*(a/L)+Fz_aero_r;
        dFz_y = m*Ay*h/track;
        Fz_fl = Fz0_f/2+roll_k_f*dFz_y; Fz_fr = Fz0_f/2-roll_k_f*dFz_y;
        Fz_rl = Fz0_r/2+roll_k_r*dFz_y; Fz_rr = Fz0_r/2-roll_k_r*dFz_y;
        Fz_all = [Fz_fl Fz_fr Fz_rl Fz_rr]; Fz_all(Fz_all<0)=0;
        Ay_new = sum(mu_func_y(Fz_all).*Fz_all)/m;
        if abs(Ay_new-Ay)<1e-5, break; end; Ay = Ay_new;
    end
    Ay_max(iV) = Ay;

    Ax = -9.81;
    for iter = 1:30
        Fz0_f = m*g*(b/L)+Fz_aero_f; Fz0_r = m*g*(a/L)+Fz_aero_r;
        dFz_x = m*Ax*h/L;
        Fz_fl = (Fz0_f-dFz_x)/2; Fz_fr = (Fz0_f-dFz_x)/2;
        Fz_rl = (Fz0_r+dFz_x)/2; Fz_rr = (Fz0_r+dFz_x)/2;
        Fz_all = [Fz_fl Fz_fr Fz_rl Fz_rr]; Fz_all(Fz_all<0)=0;
        C_f = mu_func_x(Fz_all(1))*Fz_all(1)+mu_func_x(Fz_all(2))*Fz_all(2);
        C_r = mu_func_x(Fz_all(3))*Fz_all(3)+mu_func_x(Fz_all(4))*Fz_all(4);
        Fb_f = -C_f/brake_balance; Fb_r = -C_r/(1-brake_balance);
        Ax_new = (max(Fb_f,Fb_r)-D)/m_eff;
        if abs(Ax_new-Ax)<1e-5, break; end; Ax = Ax_new;
    end
    Ax_brake(iV) = Ax;

    Ax = 5;
    for iter = 1:30
        Fz0_f = m*g*(b/L)+Fz_aero_f; Fz0_r = m*g*(a/L)+Fz_aero_r;
        dFz_x = m*Ax*h/L;
        Fz_rl = max(0,(Fz0_r+dFz_x)/2); Fz_rr = max(0,(Fz0_r+dFz_x)/2);
        C_rl = mu_func_x(Fz_rl)*Fz_rl; C_rr = mu_func_x(Fz_rr)*Fz_rr;
        Fx_rear = 2*min(C_rl,C_rr);
        Ax_new = (min(Fx_rear,power_max/V)-D)/m_eff;
        if abs(Ax_new-Ax)<1e-5, break; end; Ax = Ax_new;
    end
    Ax_drive(iV) = Ax;
end

% ---- 圈速模拟（简化版）----
n_orig = length(s);
s_3 = [s(1:end-1); s(1:end-1)+L_track; s(1:end-1)+2*L_track];
s_3 = [0; s_3];
curv_3 = [curv(1:end-1); curv(1:end-1); curv(1:end-1)];
curv_3 = [curv_3(1); curv_3];
ds_3 = diff(s_3);

Ay_interp = @(V) max(interp1(V_kmh, Ay_max, V, 'pchip','extrap'), 1e-4);
Ax_brake_interp = @(V) min(interp1(V_kmh, Ax_brake, V, 'pchip','extrap'), 0);
Ax_drive_interp = @(V) max(interp1(V_kmh, Ax_drive, V, 'pchip','extrap'), 0);

n_total = length(s_3);

% 弯道限速
V_corner = zeros(n_total,1);
for i = 1:n_total
    kap = abs(curv_3(i));
    if kap < 1e-6, V_corner(i) = V_max_kmh; continue; end
    V_corner(i) = 3.6*sqrt(Ay_interp(V_max_kmh/3.6)/kap);
end

% 前向 + 后向
V_fwd = zeros(n_total,1); V_fwd(1) = 0.5;
for i = 2:n_total
    V_curr = V_fwd(i-1); ds_i = s_3(i)-s_3(i-1);
    kap = abs(curv_3(i)); V_mps = V_curr/3.6;
    Ay_d = V_mps^2*kap;
    if Ay_d >= Ay_interp(V_curr)
        Ax_possible = 0;
    else
        Ax_possible = Ax_drive_interp(V_curr)*sqrt(1-(Ay_d/Ay_interp(V_curr))^2);
    end
    V_new = max(0.5, sqrt(max(0,V_mps^2+2*Ax_possible*ds_i))*3.6);
    V_fwd(i) = min(V_new, V_corner(i));
end

V_bwd = zeros(n_total,1); V_bwd(n_total) = 0.5;
for i = n_total-1:-1:1
    V_curr = V_bwd(i+1); ds_i = s_3(i+1)-s_3(i);
    kap = abs(curv_3(i)); V_mps = V_curr/3.6;
    Ay_d = V_mps^2*kap;
    if Ay_d >= Ay_interp(V_curr)
        Ax_possible = 0;
    else
        Ax_possible = Ax_brake_interp(V_curr)*sqrt(1-(Ay_d/Ay_interp(V_curr))^2);
    end
    V_new = max(0.5, sqrt(max(0,V_mps^2-2*Ax_possible*ds_i))*3.6);
    V_bwd(i) = min(V_new, V_fwd(i));
end

% 提取第二圈
idx_start = n_orig; idx_end = 2*n_orig-1;
V_lap = V_bwd(idx_start:idx_end);
s_lap = s_3(idx_start:idx_end) - L_track;

% 计算Ay和Ax
V_ms_lap = V_lap/3.6;
curv_lap = curv(1:end);
Ay_lap = V_ms_lap.^2 .* curv_lap;
Ax_lap = zeros(size(V_lap));
for i = 2:length(V_lap)-1
    dV2 = V_ms_lap(i+1)^2 - V_ms_lap(i-1)^2;
    ds2 = s_lap(i+1) - s_lap(i-1);
    Ax_lap(i) = 0.5*dV2/ds2;
end
Ax_lap(1)=Ax_lap(2); Ax_lap(end)=Ax_lap(end-1);

% ---- 计算每个采样点的四轮载荷 ----
n_pts = length(s_lap);
Fz_FL = zeros(n_pts,1); Fz_FR = zeros(n_pts,1);
Fz_RL = zeros(n_pts,1); Fz_RR = zeros(n_pts,1);
Fz_total = zeros(n_pts,1);

for i = 1:n_pts
    V = V_ms_lap(i);
    Ax = Ax_lap(i);
    Ay = Ay_lap(i);
    
    Fz_aero = 0.5*rho*CLA*V^2;
    Fz_aero_f = Fz_aero * aeroDistF;
    Fz_aero_r = Fz_aero * (1-aeroDistF);
    
    Fz0_f = m*g*(b/L) + Fz_aero_f;
    Fz0_r = m*g*(a/L) + Fz_aero_r;
    
    dFz_x = m * Ax * h / L;        % 制动Ax<0 → dFz_x<0 → 前加载
    dFz_y = m * abs(Ay) * h / track; % 外轮加载
    
    % 左转为正曲率 → Ay为正 → 离心力向外（右）→ 右轮加载
    % 使用实际的Ay符号
    sign_ay = sign(Ay_lap(i));
    if sign_ay == 0, sign_ay = 1; end
    
    Fz_FL(i) = (Fz0_f - dFz_x)/2 - roll_k_f * dFz_y * sign_ay;
    Fz_FR(i) = (Fz0_f - dFz_x)/2 + roll_k_f * dFz_y * sign_ay;
    Fz_RL(i) = (Fz0_r + dFz_x)/2 - roll_k_r * dFz_y * sign_ay;
    Fz_RR(i) = (Fz0_r + dFz_x)/2 + roll_k_r * dFz_y * sign_ay;
    
    Fz_total(i) = Fz_FL(i) + Fz_FR(i) + Fz_RL(i) + Fz_RR(i);
end

% ---- 统计 ----
all_Fz = [Fz_FL; Fz_FR; Fz_RL; Fz_RR];
all_Fz(all_Fz < 0) = 0;

fprintf('========== 轮胎载荷分布统计 ==========\n');
fprintf('赛道: %s (%.0f m)\n', filename, L_track);
fprintf('圈速: %.2f s (%.0f 采样点)\n\n', sum(diff(s_lap)./((V_ms_lap(1:end-1)+V_ms_lap(2:end))/2)), n_pts);

fprintf('  轮位     最小[N]   最大[N]   均值[N]   中位数[N]\n');
fprintf('  ───────  ────────  ────────  ────────  ────────\n');
for name = {'FL','FR','RL','RR'}
    fz = eval(['Fz_' name{1}]);
    fz(fz<0)=0;
    fprintf('  %s       %6.0f    %6.0f    %6.0f    %6.0f\n', name{1}, min(fz), max(fz), mean(fz), median(fz));
end

fprintf('\n  四轮合计: 均值 %.0f N, 最大 %.0f N, 最小 %.0f N\n', mean(Fz_total), max(Fz_total), min(Fz_total));

% LCO vs R20 交叉点分析
cross_point = 550;  % N
below = sum(all_Fz < cross_point) / length(all_Fz) * 100;
fprintf('\n  LCO/R20 交叉点 (%.0f N):\n', cross_point);
fprintf('  轮荷 < %.0f N 的比例: %.1f%%\n', cross_point, below);
fprintf('  轮荷 > %.0f N 的比例: %.1f%%\n', cross_point, 100-below);

% ---- 画图 ----
figure('Position', [50 50 1200 800]);

% 子图1：沿赛道载荷分布
subplot(3,2,[1 2]);
plot(s_lap, Fz_FL, 'r-', 'LineWidth', 0.8); hold on;
plot(s_lap, Fz_FR, 'b-', 'LineWidth', 0.8);
plot(s_lap, Fz_RL, 'r--', 'LineWidth', 0.8);
plot(s_lap, Fz_RR, 'b--', 'LineWidth', 0.8);
yline(cross_point, 'k--', 'LineWidth', 1);
xlabel('路程 [m]'); ylabel('轮胎载荷 [N]');
title('四轮载荷沿赛道分布');
legend('FL','FR','RL','RR',sprintf('%dN交叉点',cross_point),'Location','best');
grid on;

% 子图2：直方图
subplot(3,2,3);
histogram(Fz_FL, 30, 'FaceColor', 'r', 'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
histogram(Fz_FR, 30, 'FaceColor', 'b', 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xline(cross_point, 'k--', 'LineWidth', 1.5);
xlabel('载荷 [N]'); ylabel('频次'); title('前轮载荷分布');
legend('FL','FR',sprintf('%dN',cross_point));

subplot(3,2,4);
histogram(Fz_RL, 30, 'FaceColor', 'r', 'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
histogram(Fz_RR, 30, 'FaceColor', 'b', 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xline(cross_point, 'k--', 'LineWidth', 1.5);
xlabel('载荷 [N]'); ylabel('频次'); title('后轮载荷分布');
legend('RL','RR',sprintf('%dN',cross_point));

% 子图3：总载荷直方图
subplot(3,2,5);
histogram(all_Fz, 40, 'FaceColor', [0.3 0.3 0.3], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
xline(cross_point, 'k--', 'LineWidth', 1.5);
xlabel('载荷 [N]'); ylabel('频次'); title('全部轮荷分布');

% 子图4：速度剖面 + Ay剖面
subplot(3,2,6);
yyaxis left;
plot(s_lap, V_lap, 'b-', 'LineWidth', 1.5);
ylabel('速度 [km/h]');
yyaxis right;
plot(s_lap, Ay_lap, 'r-', 'LineWidth', 1);
ylabel('Ay [m/s^2]');
xlabel('路程 [m]'); title('速度与侧向加速度');
legend('速度','Ay');
grid on;

saveas(gcf, '轮胎载荷分布.png');
fprintf('\n图片已保存: 轮胎载荷分布.png\n');
