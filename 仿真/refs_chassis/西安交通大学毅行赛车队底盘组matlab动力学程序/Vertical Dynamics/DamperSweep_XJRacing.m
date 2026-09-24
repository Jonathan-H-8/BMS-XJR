%% Louis Ye, Oct 2025 — XJ_Racing 修改版
clc
clear
close all
addpath(genpath('D:/OH-WorkSpace/FSAE-VD-Personal-Scripts/Vertical Dynamics'));

%% Car Model Setup

car.sprungMass = 208; % kg  (XJ_Racing: 104*2)
car.pitchInertia = 30; % kg.m2  (XJ_Racing: I_yy*2)
car.unsprungMass = 8; % kg  (XJ_Racing)
car.wheelbase = 1.545; % m  (XJ_Racing)
car.CGx = 0.45; % ratio fwd  (XJ_Racing)
car.CGh = 0.3; % m  (XJ_Racing, 待确认)

car.frontInertance = 0; % kg
car.rearInertance = 0; % kg
car.frontTireStiffness = 150000; % N/m  (XJ_Racing Hoosier 18x6.0-10)
car.frontTireDamping = 40; % Ns/m
car.rearTireStiffness = 150000; % (XJ_Racing Hoosier)
car.rearTireDamping = 40;

%% Read Damper/Spring Plots
frontMR = 1.73; % Motion Ratio  (XJ_Racing)
rearMR = 1.58; % (XJ_Racing)

% 用接近你刚度的弹簧表
frontSpringCurve = SetSpringCurve(readtable("SpringTable.xlsx", "Sheet", "XJR_front_114p4Nmm"), frontMR);
rearSpringCurve = SetSpringCurve(readtable("SpringTable.xlsx", "Sheet", "XJR_rear_79p2Nmm"), rearMR);

damperTable = readtable("DamperTable.xlsx","Sheet","Multimatic_DSSV_VC01");

frontDamperCurve = SetDamperClick(damperTable, frontMR, 6, 6);
rearDamperCurve = SetDamperClick(damperTable, rearMR, 6, 6);


%% Damper Settings Sweep
for front = 1:8
    for rear = 1:8
        frontDamperCurve = SetDamperClick(damperTable, frontMR, front, front);
        rearDamperCurve = SetDamperClick(damperTable, rearMR, rear, rear);
        run = SingleRun(car, frontDamperCurve, rearDamperCurve, frontSpringCurve, rearSpringCurve);      
        KPI = CalculateKPI(run);
        frontMinCPL(front,rear) = KPI.frontMinCPL;
        rearMinCPL(front,rear) = KPI.rearMinCPL;
        frontCPLV(front,rear) = KPI.frontCPLVRMS;
        rearCPLV(front,rear) = KPI.rearCPLVRMS;
        bodyPitch(front,rear) = KPI.bodyPitchRMS;
        hubPitch(front,rear) = KPI.hubPitchRMS;
        zeta(front,rear) = KPI.heaveZeta;
    end
end
%% Data Cleanup

minCPL = (frontMinCPL + rearMinCPL)/2;
CPLV = (frontCPLV + rearCPLV)/2;

%% plot
contourLineCount = 25;
figure('Position', [100, 100, 1200, 900]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile
contourf(CPLV, contourLineCount);
grid on; colorbar('eastoutside')
xlabel("Front Damper Click"); ylabel("Rear Damper Click")
title("Total CPLV vs. Damper Settings")
subtitle('lower is better')

nexttile
contourf(frontCPLV, contourLineCount);
grid on; colorbar('eastoutside')
xlabel("Front Damper Click"); ylabel("Rear Damper Click")
title("Front CPLV vs. Damper Settings")
subtitle('lower is better')

nexttile
contourf(minCPL, contourLineCount);
grid on; colorbar('eastoutside')
xlabel("Front Damper Click"); ylabel("Rear Damper Click")
title("Min CPL vs. Damper Settings")
subtitle('higher is better')

nexttile
contourf(hubPitch, contourLineCount);
grid on; colorbar('eastoutside')
xlabel("Front Damper Click"); ylabel("Rear Damper Click")
title("Hub Pitch vs. Damper Settings")
subtitle('lower is better')

nexttile
contourf(bodyPitch, contourLineCount);
grid on; colorbar('eastoutside')
xlabel("Front Damper Click"); ylabel("Rear Damper Click")
title("Body Pitch vs. Damper Settings")
subtitle('lower is better')

nexttile
contourf(zeta, contourLineCount);
grid on; colorbar('eastoutside')
xlabel("Front Damper Click"); ylabel("Rear Damper Click")
title("Heave Zeta vs. Damper Settings")
subtitle('higher is better')

sgtitle('Damper Setting Sweep — XJ_Racing', 'FontSize', 14, 'FontWeight', 'bold')
saveas(gcf, 'D:/OH-WorkSpace/FSAE-VD-Personal-Scripts/Vertical Dynamics/XJRacing_DamperSweep_Simulink.png')
disp('Figure saved.')
