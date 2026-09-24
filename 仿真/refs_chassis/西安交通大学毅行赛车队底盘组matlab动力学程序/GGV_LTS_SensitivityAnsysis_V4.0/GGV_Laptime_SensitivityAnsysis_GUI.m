function GGV_Laptime_SensitivityAnsysis_GUI
% GGV 模型 & 圈速模拟 & 敏感性分析 整合界面（最终版）

fig = uifigure('Name', 'GGV 与圈速分析', 'Position', [50 50 1480 850]);

% ========== 整体布局：左侧车辆参数面板（420px），右侧选项卡 ==========
mainGrid = uigridlayout(fig, [1, 2], 'ColumnWidth', {420, '1x'}, 'Padding', [10 10 10 10]);

% ---- 左侧面板（车辆参数） ----
pnl = uipanel(mainGrid, 'Title', '车辆参数');
pnl.Layout.Row = 1; pnl.Layout.Column = 1;

pnlGrid = uigridlayout(pnl, [15, 4], ...
    'RowHeight', repmat({25}, 1, 15), ...
    'ColumnWidth', {105, 80, 105, 80}, ...
    'Padding', [10 10 10 10]);

% 行1：质量 / 轴距
uilabel(pnlGrid, 'Text', '质量 [kg]');      edt_m = uieditfield(pnlGrid, 'numeric', 'Value', 240);
uilabel(pnlGrid, 'Text', '轴距 [m]');       edt_L = uieditfield(pnlGrid, 'numeric', 'Value', 1.545);

% 行2：后轴静载荷比 / 轮距
uilabel(pnlGrid, 'Text', '后轴静载荷比');    edt_cog = uieditfield(pnlGrid, 'numeric', 'Value', 0.55);
uilabel(pnlGrid, 'Text', '轮距 [m]');        edt_track = uieditfield(pnlGrid, 'numeric', 'Value', 1.21);

% 行3：质心高度 / CLA
uilabel(pnlGrid, 'Text', '质心高度 [m]');    edt_h = uieditfield(pnlGrid, 'numeric', 'Value', 0.3);
uilabel(pnlGrid, 'Text', 'CLA [m^2]');       edt_CLA = uieditfield(pnlGrid, 'numeric', 'Value', 4);

% 行4：CDA / 下压力分配
uilabel(pnlGrid, 'Text', 'CDA [m^2]');       edt_CDA = uieditfield(pnlGrid, 'numeric', 'Value', 1.33);
uilabel(pnlGrid, 'Text', '前轴下压力分配');   edt_aeroDist = uieditfield(pnlGrid, 'numeric', 'Value', 0.4);

% 行5：μx0 / μy0
uilabel(pnlGrid, 'Text', 'μx0 (纵向)');      edt_mux0 = uieditfield(pnlGrid, 'numeric', 'Value', 2.6);
uilabel(pnlGrid, 'Text', 'μy0 (横向)');      edt_muy0 = uieditfield(pnlGrid, 'numeric', 'Value', 2.5);

% 行6：k_mu_x / k_mu_y
uilabel(pnlGrid, 'Text', 'k_mu_x (纵)');      edt_kmux = uieditfield(pnlGrid, 'numeric', 'Value', -0.0003);
uilabel(pnlGrid, 'Text', 'k_mu_y (横)');      edt_kmuy = uieditfield(pnlGrid, 'numeric', 'Value', -0.0003);

% 行7：kx / ky
uilabel(pnlGrid, 'Text', 'kx (纵修正)');      edt_kx = uieditfield(pnlGrid, 'numeric', 'Value', 0.65);
uilabel(pnlGrid, 'Text', 'ky (横修正)');      edt_ky = uieditfield(pnlGrid, 'numeric', 'Value', 0.65);

% 行8：前制动比 / 最大功率
uilabel(pnlGrid, 'Text', '前制动比');         edt_brakeBias = uieditfield(pnlGrid, 'numeric', 'Value', 0.65);
uilabel(pnlGrid, 'Text', '功率 [W]');         edt_power = uieditfield(pnlGrid, 'numeric', 'Value', 37000);

% 行9：赛道文件（跨两列）
uilabel(pnlGrid, 'Text', '赛道文件');         edt_trackfile = uieditfield(pnlGrid, 'text', 'Value', '2026_ChengDu.txt');

% 行10：前侧倾刚度占比（跨两列）
uilabel(pnlGrid, 'Text', '前侧倾刚度占比');    edt_rollFrac = uieditfield(pnlGrid, 'numeric', 'Value', 0.5);

% 行11：前/后侧倾中心高度
uilabel(pnlGrid, 'Text', '前侧倾中心 [mm]');    edt_rcF = uieditfield(pnlGrid, 'numeric', 'Value', 30);
uilabel(pnlGrid, 'Text', '后侧倾中心 [mm]');    edt_rcR = uieditfield(pnlGrid, 'numeric', 'Value', 60);

% 行12：前/后轮线刚度
uilabel(pnlGrid, 'Text', '前轮线刚度 [N/mm]');  edt_kwF = uieditfield(pnlGrid, 'numeric', 'Value', 38.2);
uilabel(pnlGrid, 'Text', '后轮线刚度 [N/mm]');  edt_kwR = uieditfield(pnlGrid, 'numeric', 'Value', 31.7);

% 行13：前/后角刚度
uilabel(pnlGrid, 'Text', '前角刚度 [Nm/°]');    edt_krollF = uieditfield(pnlGrid, 'numeric', 'Value', 488);
uilabel(pnlGrid, 'Text', '后角刚度 [Nm/°]');    edt_krollR = uieditfield(pnlGrid, 'numeric', 'Value', 488);

% 行14：按钮（分别占两列）
btn_ggv = uibutton(pnlGrid, 'push', 'Text', '更新 GGV 曲面', ...
    'ButtonPushedFcn', @(btn,event) updateGGV());
btn_ggv.Layout.Row = 14; btn_ggv.Layout.Column = [1 2];
btn_lap = uibutton(pnlGrid, 'push', 'Text', '计算圈速', ...
    'ButtonPushedFcn', @(btn,event) updateLaptime());
btn_lap.Layout.Row = 14; btn_lap.Layout.Column = [3 4];

% 行15：状态栏（跨四列）
lbl_status = uilabel(pnlGrid, 'Text', '就绪', ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
lbl_status.Layout.Row = 15; lbl_status.Layout.Column = [1 4];

% ---- 右侧选项卡 ----
tabgroup = uitabgroup(mainGrid);
tabgroup.Layout.Row = 1; tabgroup.Layout.Column = 2;

% 选项卡1：GGV 模型
tab1 = uitab(tabgroup, 'Title', 'GGV 模型');
grid1 = uigridlayout(tab1, [2, 3], 'RowHeight', {'3x', '2x'}, 'ColumnWidth', {'1x', '1x', '1x'});
ax_ggv_surf  = uiaxes(grid1); ax_ggv_surf.Layout.Row = 1; ax_ggv_surf.Layout.Column = [1 3];
ax_ax_curve  = uiaxes(grid1); ax_ax_curve.Layout.Row = 2; ax_ax_curve.Layout.Column = 1;
ax_ay_curve  = uiaxes(grid1); ax_ay_curve.Layout.Row = 2; ax_ay_curve.Layout.Column = 2;
ax_mu_curve  = uiaxes(grid1); ax_mu_curve.Layout.Row = 2; ax_mu_curve.Layout.Column = 3;

% 选项卡2：圈速模拟
tab2 = uitab(tabgroup, 'Title', '圈速模拟');
grid2 = uigridlayout(tab2, [4, 2], 'RowHeight', {'2x', '1.5x', '1x', '1x'}, 'ColumnWidth', {'1x', '1x'});
ax_track_map   = uiaxes(grid2); ax_track_map.Layout.Row = 1; ax_track_map.Layout.Column = 1;
ax_ggv_scatter = uiaxes(grid2); ax_ggv_scatter.Layout.Row = 1; ax_ggv_scatter.Layout.Column = 2;
ax_speed       = uiaxes(grid2); ax_speed.Layout.Row = 2; ax_speed.Layout.Column = [1 2];
ax_ax_lap      = uiaxes(grid2); ax_ax_lap.Layout.Row = 3; ax_ax_lap.Layout.Column = [1 2];
ax_ay_lap      = uiaxes(grid2); ax_ay_lap.Layout.Row = 4; ax_ay_lap.Layout.Column = [1 2];

% 选项卡3：敏感性分析
tab3 = uitab(tabgroup, 'Title', '敏感性分析');
sensGrid = uigridlayout(tab3, [1, 2], 'ColumnWidth', {400, '1x'}, 'Padding', [5 5 5 5]);

pnlSens = uigridlayout(sensGrid, [5, 1], 'RowHeight', {30, '1x', 80, 30, 75}, 'Padding', [5 5 5 5]);
pnlSens.Layout.Row = 1; pnlSens.Layout.Column = 1;

topSens = uigridlayout(pnlSens, [1, 2], 'ColumnWidth', {50, 80}, 'Padding', [5 5 5 5]);
topSens.Layout.Row = 1; topSens.Layout.Column = 1;
uilabel(topSens, 'Text', '参数个数');
dd_numParams = uidropdown(topSens, 'Items', {'2', '3'}, 'Value', '2', ...
    'ValueChangedFcn', @(src, event) updateSensParamFields());
dd_numParams.Layout.Column = 2;

gridSensParam = uigridlayout(pnlSens, [4, 5], ...
    'RowHeight', {22, 30, 30, 30}, ...
    'ColumnWidth', {120, 65, 65, 65, 65}, ...
    'Padding', [5 5 5 5]);
gridSensParam.Layout.Row = 2; gridSensParam.Layout.Column = 1;

uilabel(gridSensParam, 'Text', '参数', 'FontWeight', 'bold');
uilabel(gridSensParam, 'Text', '最小', 'FontWeight', 'bold');
uilabel(gridSensParam, 'Text', '最大', 'FontWeight', 'bold');
uilabel(gridSensParam, 'Text', '步长', 'FontWeight', 'bold');

[paramDisplay, paramCode] = getParamDisplayAndCode();

dd_sens1 = uidropdown(gridSensParam, 'Items', paramDisplay, 'ItemsData', paramCode, ...
    'Value', 'm', 'ValueChangedFcn', @(src, event) setSensDefaultRange(1));
edt_min1 = uieditfield(gridSensParam, 'numeric', 'Value', 200);
edt_max1 = uieditfield(gridSensParam, 'numeric', 'Value', 280);
edt_step1 = uieditfield(gridSensParam, 'numeric', 'Value', 10);
dd_sens1.Layout.Row = 2; dd_sens1.Layout.Column = 1;
edt_min1.Layout.Row = 2; edt_min1.Layout.Column = 2;
edt_max1.Layout.Row = 2; edt_max1.Layout.Column = 3;
edt_step1.Layout.Row = 2; edt_step1.Layout.Column = 4;

dd_sens2 = uidropdown(gridSensParam, 'Items', paramDisplay, 'ItemsData', paramCode, ...
    'Value', 'CLA', 'ValueChangedFcn', @(src, event) setSensDefaultRange(2));
edt_min2 = uieditfield(gridSensParam, 'numeric', 'Value', 3.0);
edt_max2 = uieditfield(gridSensParam, 'numeric', 'Value', 5.0);
edt_step2 = uieditfield(gridSensParam, 'numeric', 'Value', 0.25);
dd_sens2.Layout.Row = 3; dd_sens2.Layout.Column = 1;
edt_min2.Layout.Row = 3; edt_min2.Layout.Column = 2;
edt_max2.Layout.Row = 3; edt_max2.Layout.Column = 3;
edt_step2.Layout.Row = 3; edt_step2.Layout.Column = 4;

dd_sens3 = uidropdown(gridSensParam, 'Items', paramDisplay, 'ItemsData', paramCode, ...
    'Value', 'CDA', 'Visible', 'off', 'ValueChangedFcn', @(src, event) setSensDefaultRange(3));
edt_min3 = uieditfield(gridSensParam, 'numeric', 'Value', 1.0, 'Visible', 'off');
edt_max3 = uieditfield(gridSensParam, 'numeric', 'Value', 1.8, 'Visible', 'off');
edt_step3 = uieditfield(gridSensParam, 'numeric', 'Value', 0.1, 'Visible', 'off');
dd_sens3.Layout.Row = 4; dd_sens3.Layout.Column = 1;
edt_min3.Layout.Row = 4; edt_min3.Layout.Column = 2;
edt_max3.Layout.Row = 4; edt_max3.Layout.Column = 3;
edt_step3.Layout.Row = 4; edt_step3.Layout.Column = 4;

lst_history = uilistbox(pnlSens, 'Items', {}, 'ValueChangedFcn', @(src, event) showSensHistory());
lst_history.Layout.Row = 3; lst_history.Layout.Column = 1;

% 第4行：进度文字（原参数说明按钮已删除，仅保留进度文字，居中）
row4 = uigridlayout(pnlSens, [1, 1], 'ColumnWidth', {'1x'}, 'Padding', [5 5 5 5]);
row4.Layout.Row = 4; row4.Layout.Column = 1;
lbl_progress = uilabel(row4, 'Text', '就绪', 'HorizontalAlignment', 'center');

sensBottom = uigridlayout(pnlSens, [2, 1], 'RowHeight', {22, 30}, 'Padding', [5 5 5 5]);
sensBottom.Layout.Row = 5; sensBottom.Layout.Column = 1;
pg_html = uihtml(sensBottom);
pg_html.HTMLSource = sprintf(['<html><body style="margin:0">', ...
    '<progress id="p" value="0" max="100" style="width:100%%; height:20px;"></progress>', ...
    '</body></html>']);
sensBtnGrid = uigridlayout(sensBottom, [1, 3], 'ColumnWidth', {'1x','1x','1x'}, 'Padding', [0 0 0 0]);
btn_calc = uibutton(sensBtnGrid, 'push', 'Text', '开始计算', 'ButtonPushedFcn', @(btn,event) startSensCalc());
btn_load = uibutton(sensBtnGrid, 'push', 'Text', '加载结果', 'ButtonPushedFcn', @(btn,event) loadSensResults());
btn_save = uibutton(sensBtnGrid, 'push', 'Text', '保存结果', 'ButtonPushedFcn', @(btn,event) saveSensResults());

ax_sens = uiaxes(sensGrid);
ax_sens.Layout.Row = 1; ax_sens.Layout.Column = 2;

sensHistoryData = {};
sensHistoryCount = 0;

% 选项卡4：车身姿态
tab4 = uitab(tabgroup, 'Title', '车身姿态');
grid4 = uigridlayout(tab4, [2, 2], 'RowHeight', {'2x', '1x'}, 'ColumnWidth', {'1x', '1x'});
ax_attitude = uiaxes(grid4); ax_attitude.Layout.Row = 1; ax_attitude.Layout.Column = [1 2];
ax_roll_s   = uiaxes(grid4); ax_roll_s.Layout.Row = 2; ax_roll_s.Layout.Column = 1;
ax_pitch_s  = uiaxes(grid4); ax_pitch_s.Layout.Row = 2; ax_pitch_s.Layout.Column = 2;

% 设置选项卡切换回调
tabgroup.SelectionChangedFcn = @onTabChanged;

% 预加载赛道数据（共用）
try
    trackData = loadTrackData(edt_trackfile.Value);
catch
    trackData = [];
    lbl_status.Text = '赛道数据加载失败，请检查文件。';
end

updateGGV();
if ~isempty(trackData)
    updateLaptime();
end

% ============== 选项卡切换回调 ==============
    function onTabChanged(~, event)
        if strcmp(event.NewValue.Title, '敏感性分析')
            pnl.Visible = 'off';
            mainGrid.ColumnWidth = {0, '1x'};
        else
            pnl.Visible = 'on';
            mainGrid.ColumnWidth = {420, '1x'};
        end
    end

% ============== 原有回调函数 ==============
    function updateGGV()
        lbl_status.Text = '正在更新 GGV...'; drawnow;
        try
            p = getParams();
            [V_kmh, Ay_max, Ax_brake, Ax_drive] = compute_ggv_limits(p);
            
            nV = length(V_kmh); nTheta = 80;
            theta = linspace(0, 2*pi, nTheta);
            Ax_ggv = zeros(nV, nTheta); Ay_ggv = zeros(nV, nTheta);
            for iV = 1:nV
                ay = Ay_max(iV); ax_acc = Ax_drive(iV); ax_brk = Ax_brake(iV);
                for iTh = 1:nTheta
                    ct = cos(theta(iTh)); st = sin(theta(iTh));
                    if ct >= 0
                        Ax_ggv(iV,iTh) = ax_acc * ct;
                    else
                        Ax_ggv(iV,iTh) = abs(ax_brk) * ct;
                    end
                    Ay_ggv(iV,iTh) = ay * st;
                end
            end
            V_ggv = repmat(V_kmh, 1, nTheta);
            
            cla(ax_ggv_surf);
            surf(ax_ggv_surf, Ax_ggv, Ay_ggv, V_ggv, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
            xlabel(ax_ggv_surf, 'A_x [m/s^2]'); ylabel(ax_ggv_surf, 'A_y [m/s^2]');
            zlabel(ax_ggv_surf, 'Speed [km/h]'); title(ax_ggv_surf, 'GGV 曲面');
            colormap(ax_ggv_surf, jet); colorbar(ax_ggv_surf);
            view(ax_ggv_surf, 3); grid(ax_ggv_surf, 'on'); axis(ax_ggv_surf, 'tight');
            zlim(ax_ggv_surf, [0, p.V_max_kmh]);
            
            cla(ax_ax_curve);
            plot(ax_ax_curve, Ax_brake, V_kmh, 'r-', 'LineWidth', 2);
            hold(ax_ax_curve, 'on');
            plot(ax_ax_curve, Ax_drive, V_kmh, 'g-', 'LineWidth', 2);
            xlabel(ax_ax_curve, 'A_x [m/s^2]'); ylabel(ax_ax_curve, 'Speed [km/h]');
            title(ax_ax_curve, '纵向加速度极限'); legend(ax_ax_curve, '制动','驱动');
            grid(ax_ax_curve, 'on'); xlim(ax_ax_curve, [-30, 30]);
            
            cla(ax_ay_curve);
            plot(ax_ay_curve, Ay_max, V_kmh, 'm-', 'LineWidth', 2);
            hold(ax_ay_curve, 'on');
            plot(ax_ay_curve, -Ay_max, V_kmh, 'm-', 'LineWidth', 2);
            xlabel(ax_ay_curve, 'A_y [m/s^2]'); ylabel(ax_ay_curve, 'Speed [km/h]');
            title(ax_ay_curve, '横向加速度极限'); legend(ax_ay_curve, '+A_y','-A_y');
            grid(ax_ay_curve, 'on'); xlim(ax_ay_curve, [-30, 30]);
            
            cla(ax_mu_curve);
            Fz_range = linspace(0, 2000, 100);
            mu_x = p.kx * max(0, p.mu_x0 + p.k_mu_x * Fz_range);
            mu_y = p.ky * max(0, p.mu_y0 + p.k_mu_y * Fz_range);
            plot(ax_mu_curve, Fz_range, mu_x, 'r-', 'LineWidth', 2);
            hold(ax_mu_curve, 'on');
            plot(ax_mu_curve, Fz_range, mu_y, 'b-', 'LineWidth', 2);
            xlabel(ax_mu_curve, 'F_z [N]'); ylabel(ax_mu_curve, 'μ');
            title(ax_mu_curve, '轮胎摩擦系数'); legend(ax_mu_curve, 'μ_x','μ_y');
            grid(ax_mu_curve, 'on');
            
            lbl_status.Text = 'GGV 更新完成';
        catch ME
            lbl_status.Text = ['错误: ' ME.message];
        end
    end

    function updateLaptime()
        if isempty(trackData)
            lbl_status.Text = '赛道数据未加载！'; return;
        end
        lbl_status.Text = '正在计算圈速...'; drawnow;
        try
            p = getParams();
            [V_kmh, Ay_max, Ax_brake, Ax_drive] = compute_ggv_limits(p);
            [s_lap2, V_lap2, Ax_lap2, Ay_lap2, lap_time] = ...
                simulate_lap(trackData, V_kmh, Ay_max, Ax_brake, Ax_drive, p);
            
            cla(ax_track_map);
            scatter(ax_track_map, trackData.x, trackData.y, 10, trackData.curv, 'filled');
            colormap(ax_track_map, jet); colorbar(ax_track_map);
            xlabel(ax_track_map, 'X [m]'); ylabel(ax_track_map, 'Y [m]');
            title(ax_track_map, '赛道曲率分布'); axis(ax_track_map, 'equal'); grid(ax_track_map, 'on');
            
            cla(ax_ggv_scatter); hold(ax_ggv_scatter, 'on');
            nV = length(V_kmh); nTheta = 80;
            theta = linspace(0, 2*pi, nTheta);
            Ax_ggv = zeros(nV, nTheta); Ay_ggv = zeros(nV, nTheta);
            for iV = 1:nV
                ay = Ay_max(iV); ax_acc = Ax_drive(iV); ax_brk = Ax_brake(iV);
                for iTh = 1:nTheta
                    ct = cos(theta(iTh)); st = sin(theta(iTh));
                    if ct >= 0
                        Ax_ggv(iV,iTh) = ax_acc * ct;
                    else
                        Ax_ggv(iV,iTh) = abs(ax_brk) * ct;
                    end
                    Ay_ggv(iV,iTh) = ay * st;
                end
            end
            V_ggv = repmat(V_kmh, 1, nTheta);
            surf(ax_ggv_scatter, Ax_ggv, Ay_ggv, V_ggv, 'EdgeColor', 'none', 'FaceAlpha', 0.3);
            scatter3(ax_ggv_scatter, Ax_lap2, Ay_lap2, V_lap2, 10, V_lap2, 'filled');
            xlabel(ax_ggv_scatter, 'A_x [m/s^2]'); ylabel(ax_ggv_scatter, 'A_y [m/s^2]');
            zlabel(ax_ggv_scatter, 'Speed [km/h]'); title(ax_ggv_scatter, '理论 GGV 与飞驰圈散点');
            colormap(ax_ggv_scatter, jet); colorbar(ax_ggv_scatter);
            view(ax_ggv_scatter, 3); grid(ax_ggv_scatter, 'on'); axis(ax_ggv_scatter, 'tight');
            zlim(ax_ggv_scatter, [0, p.V_max_kmh]);
            hold(ax_ggv_scatter, 'off');
            
            cla(ax_speed);
            plot(ax_speed, s_lap2, V_lap2, 'b-', 'LineWidth', 2);
            xlabel(ax_speed, '路程 [m]'); ylabel(ax_speed, '速度 [km/h]');
            title(ax_speed, '飞驰圈速度剖面'); grid(ax_speed, 'on');
            ylim(ax_speed, [0, 120]);
            
            cla(ax_ax_lap);
            plot(ax_ax_lap, s_lap2, Ax_lap2, 'r-', 'LineWidth', 1.5);
            xlabel(ax_ax_lap, '路程 [m]'); ylabel(ax_ax_lap, 'A_x [m/s^2]');
            title(ax_ax_lap, '飞驰圈纵向加速度'); grid(ax_ax_lap, 'on');
            
            cla(ax_ay_lap);
            plot(ax_ay_lap, s_lap2, Ay_lap2, 'm-', 'LineWidth', 1.5);
            xlabel(ax_ay_lap, '路程 [m]'); ylabel(ax_ay_lap, 'A_y [m/s^2]');
            title(ax_ay_lap, '飞驰圈横向加速度'); grid(ax_ay_lap, 'on');
            
            % ---- 车身姿态计算 ----
            [roll_deg, pitch_deg] = compute_attitude(p, Ax_lap2, Ay_lap2);
            
            % 联合散点图：侧倾角 vs 俯仰角
            cla(ax_attitude);
            scatter(ax_attitude, roll_deg, pitch_deg, 12, V_lap2, 'filled');
            colormap(ax_attitude, jet); cb = colorbar(ax_attitude);
            cb.Label.String = '车速 [km/h]';
            xlabel(ax_attitude, '侧倾角 [°]（正=右侧下沉）');
            ylabel(ax_attitude, '俯仰角 [°]（正=制动点头）');
            title(ax_attitude, '车身姿态工况包络');
            grid(ax_attitude, 'on'); hold(ax_attitude, 'on');
            % 零线参考
            xline(ax_attitude, 0, 'k--', 'LineWidth', 0.5);
            yline(ax_attitude, 0, 'k--', 'LineWidth', 0.5);
            % 象限标注
            xL = xlim(ax_attitude); yL = ylim(ax_attitude);
            text(ax_attitude, xL(1)+0.05*diff(xL), yL(2)-0.05*diff(yL), ...
                '右转+刹车', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
            text(ax_attitude, xL(2)-0.05*diff(xL), yL(2)-0.05*diff(yL), ...
                '左转+刹车', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
            text(ax_attitude, xL(1)+0.05*diff(xL), yL(1)+0.05*diff(yL), ...
                '右转+加速', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
            text(ax_attitude, xL(2)-0.05*diff(xL), yL(1)+0.05*diff(yL), ...
                '左转+加速', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
            hold(ax_attitude, 'off');
            
            cla(ax_roll_s);
            plot(ax_roll_s, s_lap2, roll_deg, 'b-', 'LineWidth', 1.5);
            yline(ax_roll_s, 0, 'k--', 'LineWidth', 0.5);
            xlabel(ax_roll_s, '路程 [m]'); ylabel(ax_roll_s, '侧倾角 [°]');
            title(ax_roll_s, '侧倾角沿赛道变化（正=右侧下沉）'); grid(ax_roll_s, 'on');
            
            cla(ax_pitch_s);
            plot(ax_pitch_s, s_lap2, pitch_deg, 'r-', 'LineWidth', 1.5);
            yline(ax_pitch_s, 0, 'k--', 'LineWidth', 0.5);
            xlabel(ax_pitch_s, '路程 [m]'); ylabel(ax_pitch_s, '俯仰角 [°]');
            title(ax_pitch_s, '俯仰角沿赛道变化（正=制动点头）'); grid(ax_pitch_s, 'on');
            
            lbl_status.Text = sprintf('飞驰圈：%.3f 秒', lap_time);
        catch ME
            lbl_status.Text = ['错误: ' ME.message];
        end
    end

    function p = getParams()
        p.m     = edt_m.Value;        p.L     = edt_L.Value;
        p.cog_f = edt_cog.Value;      p.track = edt_track.Value;
        p.h     = edt_h.Value;        p.CLA   = edt_CLA.Value;
        p.CDA   = edt_CDA.Value;      p.aeroDistF = edt_aeroDist.Value;
        p.mu_x0 = edt_mux0.Value;     p.mu_y0 = edt_muy0.Value;
        p.k_mu_x = edt_kmux.Value;    p.k_mu_y = edt_kmuy.Value;
        p.kx    = edt_kx.Value;       p.ky    = edt_ky.Value;
        p.brake_balance = edt_brakeBias.Value;
        p.power_max = edt_power.Value;
        p.V_max_kmh  = 120;
        rollFrac = edt_rollFrac.Value;
        p.roll_k_f = max(0, min(1, rollFrac));
        p.roll_k_r = 1 - p.roll_k_f;
        % 悬架姿态参数
        p.rc_f    = edt_rcF.Value / 1000;     % mm -> m
        p.rc_r    = edt_rcR.Value / 1000;
        p.kw_f    = edt_kwF.Value * 1000;     % N/mm -> N/m
        p.kw_r    = edt_kwR.Value * 1000;
        p.kroll_f = edt_krollF.Value * 180/pi; % Nm/° -> Nm/rad
        p.kroll_r = edt_krollR.Value * 180/pi;
    end

% ============== 敏感性分析回调函数 ==============
    function updateSensParamFields()
        n = str2double(dd_numParams.Value);
        if n == 2
            dd_sens3.Visible = 'off';
            edt_min3.Visible = 'off'; edt_max3.Visible = 'off'; edt_step3.Visible = 'off';
        else
            dd_sens3.Visible = 'on';
            edt_min3.Visible = 'on'; edt_max3.Visible = 'on'; edt_step3.Visible = 'on';
        end
    end

    function setSensDefaultRange(idx)
        paramCode = '';
        if idx == 1, paramCode = dd_sens1.Value; end
        if idx == 2, paramCode = dd_sens2.Value; end
        if idx == 3, paramCode = dd_sens3.Value; end
        if isempty(paramCode), return; end
        def = getDefaultRange(paramCode);
        if idx == 1
            edt_min1.Value = def.min; edt_max1.Value = def.max; edt_step1.Value = def.step;
        elseif idx == 2
            edt_min2.Value = def.min; edt_max2.Value = def.max; edt_step2.Value = def.step;
        elseif idx == 3
            edt_min3.Value = def.min; edt_max3.Value = def.max; edt_step3.Value = def.step;
        end
    end

    function startSensCalc()
        if isempty(trackData)
            lbl_progress.Text = '请先加载赛道数据！'; return;
        end
        n = str2double(dd_numParams.Value);
        paramCodes = {dd_sens1.Value, dd_sens2.Value};
        if n == 3, paramCodes{3} = dd_sens3.Value; end
        
        has_LDR = ismember('LDR', paramCodes);
        has_CLA = ismember('CLA', paramCodes);
        has_CDA = ismember('CDA', paramCodes);
        has_P2W = ismember('P2W', paramCodes);
        has_m = ismember('m', paramCodes);
        has_power = ismember('power_max', paramCodes);
        if has_LDR && has_CLA && has_CDA
            lbl_progress.Text = '错误：LDR、CLA、CDA 不能三者同时选择！'; return;
        end
        if has_P2W && has_m && has_power
            lbl_progress.Text = '错误：P2W、m、功率 不能三者同时选择！'; return;
        end

        min1 = edt_min1.Value; max1 = edt_max1.Value; step1 = edt_step1.Value;
        min2 = edt_min2.Value; max2 = edt_max2.Value; step2 = edt_step2.Value;
        if n == 3
            min3 = edt_min3.Value; max3 = edt_max3.Value; step3 = edt_step3.Value;
        end
        
        vec1 = min1:step1:max1;
        vec2 = min2:step2:max2;
        if n == 3, vec3 = min3:step3:max3; end
        
        n1 = length(vec1); n2 = length(vec2);
        if n == 2
            total = n1 * n2;
            dimStr = sprintf('%d×%d = %d', n1, n2, total);
        else
            n3 = length(vec3);
            total = n1 * n2 * n3;
            dimStr = sprintf('%d×%d×%d = %d', n1, n2, n3, total);
        end
        
        disp1 = getParamDisplayName(paramCodes{1});
        disp2 = getParamDisplayName(paramCodes{2});
        if n == 3, disp3 = getParamDisplayName(paramCodes{3}); end
        
        lbl_progress.Text = ['准备计算 ' disp1 ' × ' disp2 ' (' dimStr ' 个点)...']; drawnow;
        
        p0 = getParams();
        
        function progressMsg(msg, percent)
            lbl_progress.Text = msg;
            pg_html.HTMLSource = sprintf(['<html><body style="margin:0">', ...
                '<progress id="p" value="%.0f" max="100" style="width:100%%; height:20px;"></progress>', ...
                '</body></html>'], percent);
            drawnow;
        end

        try
            if n == 2
                [X, Y, LapTimes] = scan2D(p0, trackData, paramCodes{1}, paramCodes{2}, vec1, vec2, @progressMsg);
                cla(ax_sens);
                contourf(ax_sens, X, Y, LapTimes, 20, 'LineColor', 'none');
                xlabel(ax_sens, disp1); ylabel(ax_sens, disp2);
                title(ax_sens, '圈速敏感性');
                colormap(ax_sens, parula); colorbar(ax_sens);
                grid(ax_sens, 'on');
                sensHistoryCount = sensHistoryCount + 1;
                rec.type = '2D';
                rec.X = X; rec.Y = Y; rec.LapTimes = LapTimes;
                rec.paramCodes = paramCodes; rec.paramDisps = {disp1, disp2};
                rec.scanRanges = {vec1, vec2};
                sensHistoryData{sensHistoryCount} = rec;
                desc = sprintf('[%d] %s × %s (%d×%d)', sensHistoryCount, disp1, disp2, n1, n2);
            else
                [X, Y, Z, LapTimes] = scan3D(p0, trackData, paramCodes{1}, paramCodes{2}, paramCodes{3}, vec1, vec2, vec3, @progressMsg);
                cla(ax_sens); hold(ax_sens, 'on');
                nZ = length(vec3);
                cmap = lines(nZ);
                h_leg = [];
                for iz = 1:nZ
                    surf(ax_sens, X(:,:,iz), Y(:,:,iz), LapTimes(:,:,iz), ...
                        'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', cmap(iz,:));
                    h_leg(iz) = plot3(ax_sens, NaN, NaN, NaN, 'Color', cmap(iz,:), 'LineWidth', 2);
                end
                xlabel(ax_sens, disp1); ylabel(ax_sens, disp2); zlabel(ax_sens, '圈速 [s]');
                legend(ax_sens, h_leg, arrayfun(@(v) sprintf('%s=%.2f', disp3, v), vec3, 'UniformOutput', false), 'Location', 'best');
                colormap(ax_sens, parula); colorbar(ax_sens);
                view(ax_sens, 3); grid(ax_sens, 'on');
                hold(ax_sens, 'off');
                sensHistoryCount = sensHistoryCount + 1;
                rec.type = '3D';
                rec.X = X; rec.Y = Y; rec.Z = Z; rec.LapTimes = LapTimes;
                rec.paramCodes = paramCodes; rec.paramDisps = {disp1, disp2, disp3};
                rec.scanRanges = {vec1, vec2, vec3};
                sensHistoryData{sensHistoryCount} = rec;
                desc = sprintf('[%d] %s × %s × %s (%d×%d×%d)', sensHistoryCount, disp1, disp2, disp3, n1, n2, n3);
            end
            items = lst_history.Items;
            items{end+1} = desc;
            lst_history.Items = items;
            lst_history.Value = items{end};
            lbl_progress.Text = '计算完成';
        catch ME
            lbl_progress.Text = ['错误: ' ME.message];
        end
    end

    function showSensHistory()
        sel = lst_history.Value;
        if isempty(sel), return; end
        idx = find(strcmp(lst_history.Items, sel), 1);
        if isempty(idx) || idx > length(sensHistoryData), return; end
        rec = sensHistoryData{idx};
        cla(ax_sens);
        if strcmp(rec.type, '2D')
            contourf(ax_sens, rec.X, rec.Y, rec.LapTimes, 20, 'LineColor', 'none');
            xlabel(ax_sens, rec.paramDisps{1}); ylabel(ax_sens, rec.paramDisps{2});
            title(ax_sens, '圈速敏感性 (历史)');
            colormap(ax_sens, parula); colorbar(ax_sens);
            grid(ax_sens, 'on');
        else
            hold(ax_sens, 'on');
            nZ = length(rec.scanRanges{3});
            cmap = lines(nZ);
            h_leg = [];
            for iz = 1:nZ
                surf(ax_sens, rec.X(:,:,iz), rec.Y(:,:,iz), rec.LapTimes(:,:,iz), ...
                    'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', cmap(iz,:));
                h_leg(iz) = plot3(ax_sens, NaN, NaN, NaN, 'Color', cmap(iz,:), 'LineWidth', 2);
            end
            xlabel(ax_sens, rec.paramDisps{1}); ylabel(ax_sens, rec.paramDisps{2}); zlabel(ax_sens, '圈速 [s]');
            legend(ax_sens, h_leg, arrayfun(@(v) sprintf('%s=%.2f', rec.paramDisps{3}, v), rec.scanRanges{3}, 'UniformOutput', false), 'Location', 'best');
            colormap(ax_sens, parula); colorbar(ax_sens);
            view(ax_sens, 3); grid(ax_sens, 'on');
            hold(ax_sens, 'off');
        end
    end

    function loadSensResults()
        [file, path] = uigetfile('*.mat', '选择结果文件');
        if isequal(file, 0), return; end
        loaded = load(fullfile(path, file));
        if isfield(loaded, 'X') && isfield(loaded, 'Y') && isfield(loaded, 'LapTimes')
            if ndims(loaded.LapTimes) == 2
                contourf(ax_sens, loaded.X, loaded.Y, loaded.LapTimes, 20, 'LineColor', 'none');
                xlabel(ax_sens, loaded.paramDisps{1}); ylabel(ax_sens, loaded.paramDisps{2});
                colormap(ax_sens, parula); colorbar(ax_sens); grid(ax_sens, 'on');
            else
                cla(ax_sens); hold(ax_sens, 'on');
                nZ = size(loaded.LapTimes, 3);
                cmap = lines(nZ);
                z_vals = loaded.scanRanges{3};
                for iz = 1:nZ
                    surf(ax_sens, loaded.X(:,:,iz), loaded.Y(:,:,iz), loaded.LapTimes(:,:,iz), ...
                        'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', cmap(iz,:));
                end
                xlabel(ax_sens, loaded.paramDisps{1}); ylabel(ax_sens, loaded.paramDisps{2}); zlabel(ax_sens, '圈速');
                legend(arrayfun(@(v) sprintf('%s=%.2f', loaded.paramDisps{3}, v), z_vals, 'UniformOutput', false), 'Location', 'best');
                colormap(ax_sens, parula); colorbar(ax_sens); view(ax_sens, 3); grid(ax_sens, 'on');
                hold(ax_sens, 'off');
            end
            lbl_progress.Text = '结果已加载';
        else
            lbl_progress.Text = '无效的结果文件';
        end
    end

    function saveSensResults()
        lbl_progress.Text = '保存功能：请手动使用 save 命令保存工作区变量。';
    end
end

% ================= 外部辅助函数 =================
function trackData = loadTrackData(filename)
    fid = fopen(filename, 'r');
    data = [];
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line) || isempty(strtrim(line)), continue; end
        nums = sscanf(line, '%f');
        if length(nums) < 5, continue; end  % skip non-data header lines
        data = [data; nums'];
    end
    fclose(fid);
    x = double(data(:,2)); y = double(data(:,3));
    dx = diff(x); dy = diff(y);
    ds_seg = sqrt(dx.^2 + dy.^2);
    s = [0; cumsum(ds_seg)];
    dx_ds = gradient(x, s); dy_ds = gradient(y, s);
    d2x_ds2 = gradient(dx_ds, s); d2y_ds2 = gradient(dy_ds, s);
    curv_signed = (dx_ds .* d2y_ds2 - dy_ds .* d2x_ds2) ./ (dx_ds.^2 + dy_ds.^2).^(3/2);
    trackData.x = x; trackData.y = y; trackData.s = s;
    trackData.curv = curv_signed; trackData.L = s(end);
end

function [s_lap2, V_lap2, Ax_lap2, Ay_lap2, lap_time] = simulate_lap(trackData, V_kmh, Ay_max, Ax_brake, Ax_drive, p)
    s_orig = trackData.s; curv_orig = trackData.curv; L = trackData.L;
    curv = [curv_orig(1:end-1); curv_orig(1:end-1); curv_orig];
    ds_seg_orig = diff(s_orig);
    ds_seg = [ds_seg_orig; ds_seg_orig; ds_seg_orig];
    s = [0; cumsum(ds_seg)];
    n_total = length(s);

    Ay_max_interp = @(V) max(interp1(V_kmh, Ay_max, V, 'pchip', 'extrap'), 1e-4);
    Ax_drive_interp = @(V) max(interp1(V_kmh, Ax_drive, V, 'pchip', 'extrap'), 0);
    Ax_brake_interp = @(V) min(interp1(V_kmh, Ax_brake, V, 'pchip', 'extrap'), 0);

    V_corner = p.V_max_kmh * ones(n_total,1);
    for i = 1:n_total
        kap = abs(curv(i));
        if kap < 1e-6, continue; end
        V_low = 0.5; V_high = p.V_max_kmh;
        f_low = V_low - 3.6 * sqrt( max(Ay_max_interp(V_low), 1e-4) / kap );
        f_high = V_high - 3.6 * sqrt( max(Ay_max_interp(V_high), 1e-4) / kap );
        if f_high <= 0, V_corner(i) = p.V_max_kmh; continue; end
        if f_low >= 0, V_corner(i) = 0.5; continue; end
        for iter = 1:50
            V_mid = (V_low + V_high) / 2;
            f_mid = V_mid - 3.6 * sqrt( max(Ay_max_interp(V_mid), 1e-4) / kap );
            if abs(f_mid) < 1e-4 || (V_high - V_low) < 0.01, break; end
            if f_mid > 0, V_high = V_mid; else, V_low = V_mid; end
        end
        V_corner(i) = (V_low + V_high) / 2;
    end

    V_fwd = zeros(n_total,1); V_fwd(1) = 0.5;
    for i = 2:n_total
        V_curr = V_fwd(i-1); ds = s(i) - s(i-1);
        kap_cur = abs(curv(i)); V_mps = V_curr / 3.6;
        Ay_demand = V_mps^2 * kap_cur;
        Ay_max_curr = max(Ay_max_interp(V_curr), 1e-4);
        if Ay_demand >= Ay_max_curr
            Ax_possible = 0;
        else
            ratio = sqrt(1 - (Ay_demand / Ay_max_curr)^2);
            Ax_possible = max(Ax_drive_interp(V_curr), 0) * ratio;
        end
        V_new_sq = V_mps^2 + 2 * Ax_possible * ds;
        V_new_kmh = max(0.5, sqrt(max(0,V_new_sq)) * 3.6);
        V_fwd(i) = min(V_new_kmh, V_corner(i));
    end

    V_bwd = zeros(n_total,1); V_bwd(n_total) = 0.5;
    for i = n_total-1:-1:1
        V_curr = V_bwd(i+1); ds = s(i+1) - s(i);
        kap_cur = abs(curv(i)); V_mps = V_curr / 3.6;
        Ay_demand = V_mps^2 * kap_cur;
        Ay_max_curr = max(Ay_max_interp(V_curr), 1e-4);
        if Ay_demand >= Ay_max_curr
            Ax_possible = 0;
        else
            ratio = sqrt(1 - (Ay_demand / Ay_max_curr)^2);
            Ax_possible = min(Ax_brake_interp(V_curr), 0) * ratio;
        end
        V_new_sq = V_mps^2 - 2 * Ax_possible * ds;
        V_new_kmh = max(0.5, sqrt(max(0,V_new_sq)) * 3.6);
        V_bwd(i) = min(V_new_kmh, V_fwd(i));
    end
    V_profile_full = V_bwd;

    n_orig = length(s_orig);
    idx_start = n_orig; idx_end = 2*n_orig - 1;
    V_lap2 = V_profile_full(idx_start:idx_end);
    s_lap2 = s(idx_start:idx_end) - L;

    dt = diff(s_lap2) ./ ((V_lap2(1:end-1) + V_lap2(2:end)) / 2 / 3.6);
    lap_time = sum(dt);

    V_ms = V_lap2 / 3.6;
    curv_lap2 = curv_orig(1:end);
    Ay_lap2 = V_ms.^2 .* curv_lap2;
    Ax_lap2 = zeros(size(V_lap2));
    for i = 2:length(V_lap2)-1
        dV2 = V_ms(i+1)^2 - V_ms(i-1)^2;
        ds2 = s_lap2(i+1) - s_lap2(i-1);
        Ax_lap2(i) = 0.5 * dV2 / ds2;
    end
    Ax_lap2(1) = Ax_lap2(2); Ax_lap2(end) = Ax_lap2(end-1);
end

function [roll_deg, pitch_deg] = compute_attitude(p, Ax, Ay)
    % 计算车身侧倾角和俯仰角
    %   roll_deg: 侧倾角 [°]，正=右侧下沉（左转），负=左侧下沉（右转）
    %   pitch_deg: 俯仰角 [°]，正=车头下沉（制动点头），负=车头抬起（加速后坐）
    
    m = p.m; L = p.L; h = p.h;
    
    % --- 侧倾角 ---
    kroll_total = p.kroll_f + p.kroll_r;
    if kroll_total > 0
        h_rc_eff = (p.rc_f * p.kroll_f + p.rc_r * p.kroll_r) / kroll_total;
    else
        h_rc_eff = 0;
    end
    
    roll_moment = m * abs(Ay) * (h - h_rc_eff);
    roll_rad = roll_moment / max(kroll_total, 1);
    % 左转(Ay<0)→离心力向右→车身右侧下沉→侧倾角为正
    roll_deg = -roll_rad * 180 / pi .* sign(Ay);
    
    % --- 俯仰角 ---
    % 纵向载荷转移：ΔFz = m * Ax * h / L（制动时 Ax<0，ΔFz<0）
    delta_Fz = m * Ax * h / L;
    
    % 前轴底盘位移（正=向上）：制动时压缩→负值
    deflect_f = delta_Fz ./ (2 * p.kw_f);
    % 后轴底盘位移（正=向上）：制动时拉伸→正值
    deflect_r = -delta_Fz ./ (2 * p.kw_r);
    
    % 俯仰角：车头下沉（制动点头）为正
    pitch_rad = (deflect_r - deflect_f) / L;
    pitch_deg = pitch_rad * 180 / pi;
end

function [V_kmh, Ay_lat, Ax_brake, Ax_drive] = compute_ggv_limits(p)
    m = p.m; L = p.L; a = p.cog_f * L; b = L - a;
    tf = p.track; tr = p.track; h = p.h;
    CLA = p.CLA; CDA = p.CDA;
    aeroDistF = p.aeroDistF; aeroDistR = 1 - aeroDistF;
    mu_x0 = p.mu_x0; mu_y0 = p.mu_y0;
    k_mu_x = p.k_mu_x; k_mu_y = p.k_mu_y;
    kx = p.kx; ky = p.ky;
    mu_func_x = @(Fz) kx * max(0, mu_x0 + k_mu_x * Fz);
    mu_func_y = @(Fz) ky * max(0, mu_y0 + k_mu_y * Fz);
    brake_balance = p.brake_balance;
    power_max = p.power_max;
    V_max_kmh = p.V_max_kmh;
    roll_k_f = p.roll_k_f; roll_k_r = p.roll_k_r;

    % ---- 车轮转动惯量修正 (Hoosier 43075 16x7.5-10) ----
    Iw = 0.16;        % 单轮转动惯量 [kg·m²]（轮胎+轮辋+刹车盘）
    r_eff = 0.204;    % 有效滚动半径 [m]（自由半径0.2057m，略减）
    m_eff = m + 4 * Iw / r_eff^2;  % 等效质量：含四轮旋转惯性

    g = 9.81; rho = 1.225;

    V_kmh_min = 0.5; nV = 25;
    V_kmh = linspace(V_kmh_min, V_max_kmh, nV)';
    V_ms  = V_kmh / 3.6;

    Ay_lat = zeros(nV,1); Ax_brake = zeros(nV,1); Ax_drive = zeros(nV,1);

    for iV = 1:nV
        V = V_ms(iV);
        D = 0.5 * rho * CDA * V^2;
        Fz_aero = 0.5 * rho * CLA * V^2;
        Fz_aero_f = Fz_aero * aeroDistF;
        Fz_aero_r = Fz_aero * aeroDistR;

        Ay = 9.81;
        for iter = 1:30
            Fz0_f = m*g*(b/L) + Fz_aero_f;
            Fz0_r = m*g*(a/L) + Fz_aero_r;
            delta_Fz_y = m * Ay * h / ((tf+tr)/2);
            Fz_fl = Fz0_f/2 + roll_k_f*delta_Fz_y;
            Fz_fr = Fz0_f/2 - roll_k_f*delta_Fz_y;
            Fz_rl = Fz0_r/2 + roll_k_r*delta_Fz_y;
            Fz_rr = Fz0_r/2 - roll_k_r*delta_Fz_y;
            Fz_all = [Fz_fl, Fz_fr, Fz_rl, Fz_rr];
            Fz_all(Fz_all < 0) = 0;
            C = mu_func_y(Fz_all) .* Fz_all;
            Ay_new = sum(C)/m;
            if abs(Ay_new-Ay)<1e-5, break; end
            Ay = Ay_new;
        end
        Ay_lat(iV) = Ay;

        Ax = -9.81;
        for iter = 1:30
            Fz0_f = m*g*(b/L) + Fz_aero_f;
            Fz0_r = m*g*(a/L) + Fz_aero_r;
            delta_Fz_x = m * Ax * h / L;
            Fz_fl = (Fz0_f - delta_Fz_x)/2;
            Fz_fr = (Fz0_f - delta_Fz_x)/2;
            Fz_rl = (Fz0_r + delta_Fz_x)/2;
            Fz_rr = (Fz0_r + delta_Fz_x)/2;
            Fz_all = [Fz_fl, Fz_fr, Fz_rl, Fz_rr];
            Fz_all(Fz_all < 0) = 0;
            C_f = mu_func_x(Fz_all(1))*Fz_all(1) + mu_func_x(Fz_all(2))*Fz_all(2);
            C_r = mu_func_x(Fz_all(3))*Fz_all(3) + mu_func_x(Fz_all(4))*Fz_all(4);
            Fb_f = -C_f / brake_balance;
            Fb_r = -C_r / (1-brake_balance);
            Fb_total = max(Fb_f, Fb_r);
            Ax_new = (Fb_total - D)/m_eff;
            if abs(Ax_new-Ax)<1e-5, break; end
            Ax = Ax_new;
        end
        Ax_brake(iV) = Ax;

        Ax = 5;
        for iter = 1:30
            Fz0_f = m*g*(b/L) + Fz_aero_f;
            Fz0_r = m*g*(a/L) + Fz_aero_r;
            delta_Fz_x = m * Ax * h / L;
            Fz_rl = max(0, (Fz0_r + delta_Fz_x)/2);
            Fz_rr = max(0, (Fz0_r + delta_Fz_x)/2);
            C_rl = mu_func_x(Fz_rl)*Fz_rl;
            C_rr = mu_func_x(Fz_rr)*Fz_rr;
            Fx_rear = 2 * min(C_rl, C_rr);
            Fx_limit = min(Fx_rear, power_max/V);
            Ax_new = (Fx_limit - D)/m_eff;
            if abs(Ax_new-Ax)<1e-5, break; end
            Ax = Ax_new;
        end
        Ax_drive(iV) = Ax;
    end
end

% ================= 敏感性分析专用辅助函数 =================
function [displayList, codeList] = getParamDisplayAndCode()
    mapping = {
        '质量 [kg]',                'm';
        '轴距 [m]',                 'L';
        '后轴静载荷比',             'cog_f';
        '轮距 [m]',                 'track';
        '质心高度 [m]',             'h';
        'CLA [m^2]',               'CLA';
        'CDA [m^2]',               'CDA';
        '前轴下压力分配',           'aeroDistF';
        'μx0 (纵向)',              'mu_x0';
        'μy0 (横向)',              'mu_y0';
        'k_mu_x (纵)',             'k_mu_x';
        'k_mu_y (横)',             'k_mu_y';
        'kx (纵修正)',             'kx';
        'ky (横修正)',             'ky';
        '前制动比',                'brake_balance';
        '功率 [W]',                'power_max';
        '前侧倾刚度占比',          'roll_k_f';
        '升阻比 (CLA/CDA)',        'LDR';
        '功率质量比 [W/kg]',       'P2W'
    };
    displayList = mapping(:,1);
    codeList = mapping(:,2);
end

function dispName = getParamDisplayName(code)
    [displayList, codeList] = getParamDisplayAndCode();
    idx = find(strcmp(codeList, code), 1);
    if isempty(idx)
        dispName = code;
    else
        dispName = displayList{idx};
    end
end

function def = getDefaultRange(param)
    switch param
        case 'm',          def = struct('min',200,'max',280,'step',10);
        case 'L',          def = struct('min',1.4,'max',1.7,'step',0.05);
        case 'cog_f',      def = struct('min',0.45,'max',0.65,'step',0.02);
        case 'track',      def = struct('min',1.0,'max',1.4,'step',0.05);
        case 'h',          def = struct('min',0.2,'max',0.4,'step',0.02);
        case 'CLA',        def = struct('min',3.0,'max',5.0,'step',0.25);
        case 'CDA',        def = struct('min',1.0,'max',1.8,'step',0.1);
        case 'aeroDistF',  def = struct('min',0.3,'max',0.5,'step',0.05);
        case 'mu_x0',      def = struct('min',1.2,'max',1.8,'step',0.1);
        case 'mu_y0',      def = struct('min',1.3,'max',1.9,'step',0.1);
        case 'k_mu_x',     def = struct('min',-0.0005,'max',-0.0001,'step',0.00005);
        case 'k_mu_y',     def = struct('min',-0.0005,'max',-0.0001,'step',0.00005);
        case 'kx',         def = struct('min',0.8,'max',1.2,'step',0.05);
        case 'ky',         def = struct('min',0.8,'max',1.2,'step',0.05);
        case 'brake_balance', def = struct('min',0.55,'max',0.75,'step',0.02);
        case 'power_max',  def = struct('min',30000,'max',50000,'step',2000);
        case 'roll_k_f',   def = struct('min',0.3,'max',0.7,'step',0.05);
        case 'LDR',        def = struct('min',2.0,'max',5.0,'step',0.5);
        case 'P2W',        def = struct('min',100,'max',200,'step',10);
        otherwise,         def = struct('min',0,'max',1,'step',0.1);
    end
end

function p = applyParamValue(p, paramName, value)
    switch paramName
        case 'LDR'
            p.LDR_value = value;
        case 'P2W'
            p.P2W_value = value;
        otherwise
            p.(paramName) = value;
    end
end

function p = resolve_dependencies(p, paramNames)
    has_CLA = ismember('CLA', paramNames);
    has_CDA = ismember('CDA', paramNames);
    has_LDR = ismember('LDR', paramNames);
    has_m = ismember('m', paramNames);
    has_power = ismember('power_max', paramNames);
    has_P2W = ismember('P2W', paramNames);
    
    if has_LDR
        LDR_val = p.LDR_value;
        if has_CLA && ~has_CDA
            p.CDA = p.CLA / LDR_val;
        elseif has_CDA && ~has_CLA
            p.CLA = p.CDA * LDR_val;
        end
        p = rmfield(p, 'LDR_value');
    end
    
    if has_P2W
        P2W_val = p.P2W_value;
        if has_m && ~has_power
            p.power_max = P2W_val * p.m;
        elseif has_power && ~has_m
            p.m = p.power_max / P2W_val;
        end
        p = rmfield(p, 'P2W_value');
    end
end

function [X, Y, LapTimes] = scan2D(p0, trackData, param1, param2, vec1, vec2, progressFn)
    [X, Y] = meshgrid(vec1, vec2);
    nRows = size(X,1); nCols = size(X,2);
    total = numel(X);
    LapTimes = zeros(size(X));
    count = 0;
    for i = 1:nRows
        for j = 1:nCols
            p = p0;
            p = applyParamValue(p, param1, X(i,j));
            p = applyParamValue(p, param2, Y(i,j));
            p = resolve_dependencies(p, {param1, param2});
            [V, Ay, Axb, Axd] = compute_ggv_limits(p);
            [~,~,~,~, LapTimes(i,j)] = simulate_lap(trackData, V, Ay, Axb, Axd, p);
            count = count + 1;
            if mod(count, max(1, round(total/100))) == 0 || count == total
                percent = round(count/total*100);
                progressFn(sprintf('(%d,%d)/%dx%d  (%d%%)', i, j, nRows, nCols, percent), percent);
            end
        end
    end
end

function [X, Y, Z, LapTimes] = scan3D(p0, trackData, param1, param2, param3, vec1, vec2, vec3, progressFn)
    [X, Y, Z] = meshgrid(vec1, vec2, vec3);
    nD1 = size(X,1); nD2 = size(X,2); nD3 = size(X,3);
    total = numel(X);
    LapTimes = zeros(size(X));
    count = 0;
    for i = 1:nD1
        for j = 1:nD2
            for k = 1:nD3
                p = p0;
                p = applyParamValue(p, param1, X(i,j,k));
                p = applyParamValue(p, param2, Y(i,j,k));
                p = applyParamValue(p, param3, Z(i,j,k));
                p = resolve_dependencies(p, {param1, param2, param3});
                [V, Ay, Axb, Axd] = compute_ggv_limits(p);
                [~,~,~,~, LapTimes(i,j,k)] = simulate_lap(trackData, V, Ay, Axb, Axd, p);
                count = count + 1;
                if mod(count, max(1, round(total/100))) == 0 || count == total
                    percent = round(count/total*100);
                    progressFn(sprintf('(%d,%d,%d)/%dx%dx%d  (%d%%)', i, j, k, nD1, nD2, nD3, percent), percent);
                end
            end
        end
    end
end