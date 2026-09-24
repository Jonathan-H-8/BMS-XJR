%% LCO 43075 — 一键拟合 + 出图
% 炳森 | 西安交通大学毅行赛车队 | 2026-06
% 用法: 直接运行本脚本即可
clear; clc;

%% ═══════════ 全局变量 ═══════════
global FZ0 R0
global PCY1 PDY1 PDY2 PDY3 PEY1 PEY2 PEY3 PEY4 ...
       PKY1 PKY2 PKY3 PHY1 PHY2 PHY3 PVY1 PVY2 PVY3 PVY4
global QBZ1 QBZ2 QBZ3 QBZ4 QBZ5 QBZ9 QBZ10 QCZ1 QDZ1 QDZ2 QDZ3 ...
       QDZ4 QDZ6 QDZ7 QDZ8 QDZ9 QEZ1 QEZ2 QEZ3 QEZ4 QEZ5 ...
       QHZ1 QHZ2 QHZ3 QHZ4
global LFZO LCX LMUX LEX LKX LHX LVX LCY LMUY LEY LKY LHY LVY ...
       LGAY LTR LRES LGAZ LXAL LYKA LVYKA LS LSGKP LSGAL LGYR

R0 = 0.205;
LFZO=1;LCX=1;LMUX=1;LEX=1;LKX=1;LHX=1;LVX=1;
LCY=1;LMUY=1;LEY=1;LKY=1;LHY=1;LVY=1;
LGAY=1;LTR=1;LRES=1;LGAZ=1;LXAL=1;LYKA=1;LVYKA=1;
LS=1;LSGKP=1;LSGAL=1;LGYR=1;

%% ═══════════ 1. 加载数据 ═══════════
fprintf('=== 43075 R20 MF5.2 ===\n');
fprintf('Loading data...\n');
dataDir = '数据\Round9_mat';
SA_r=[]; FZ_r=[]; FY_r=[]; MZ_r=[]; IA_r=[]; P_r=[];
for rn=[4,5,6]
    load(fullfile(dataDir, sprintf('B2356run%d.mat', rn)));
    SA_r=[SA_r; SA(:)]; FZ_r=[FZ_r; FZ(:)]; FY_r=[FY_r; FY(:)];
    MZ_r=[MZ_r; MZ(:)]; IA_r=[IA_r; IA(:)]; P_r=[P_r; P(:)];
end
FZ_r = abs(FZ_r);
fprintf('  Loaded %d points (runs 18,19)\n', length(SA_r));

%% ═══════════ 2. 数据清洗: 只保留 |SA| 上升段 ═══════════
fprintf('Cleaning hysteresis...\n');
n=length(SA_r); keep=false(n,1); in_sweep=false; sweep_start=1; going_up=true;
for i=2:n
    if ~in_sweep && abs(SA_r(i))>2
        in_sweep=true; sweep_start=i; going_up=true;
    end
    if in_sweep
        if i>sweep_start+5
            prev=mean(abs(SA_r(i-5:i-1)));
            if going_up && abs(SA_r(i))<prev*0.92, going_up=false; end
        end
        if going_up, keep(i)=true; end
        if abs(SA_r(i))<1 && i>sweep_start+20, in_sweep=false; end
    end
end
SA_r=SA_r(keep);FZ_r=FZ_r(keep);FY_r=FY_r(keep);MZ_r=MZ_r(keep);IA_r=IA_r(keep);P_r=P_r(keep);
fprintf('  %d points retained (%.0f%%)\n', sum(keep), sum(keep)/n*100);

%% ═══════════ 3. 拟合 (IA≈0°, 所有压力) ═══════════
fprintf('Fitting...\n');
mask = abs(IA_r) < 0.5;
SA = SA_r(mask); FZ = FZ_r(mask); FY = FY_r(mask); MZ = MZ_r(mask);

SA_g=round(SA*2)/2; FZ_g=round(FZ/50)*50;
[~,~,ic]=unique([SA_g,FZ_g],'rows'); nG=max(ic);
SA_m=accumarray(ic,SA,[],@mean); FZ_m=accumarray(ic,FZ,[],@mean);
FY_m=accumarray(ic,FY,[],@mean); MZ_m=accumarray(ic,MZ,[],@mean);
FZ0=mean(FZ_m); INPUT=[SA_m,FZ_m,zeros(nG,1)];
fprintf('  %d grid points (FZ0=%.0f N)\n', nG, FZ0);

% Fy 拟合
lb=[-2.5,-8,-5,-1,-10,-2,-10,-5,-100,0.5,-1,-0.1,-0.1,-1,-1,-5,0,-20];
ub=[-0.3,-0.5,5,5,10,2,10,5,-2,10,0.5,0.1,0.1,1,1,5,5,20];
p0=[-1.2,-2.5,-0.15,0,0.5,-0.1,0,-2,-40,2.5,2,0.002,0.002,-0.1,0.01,0.01,-1,-0.1];
opts=optimset('MaxFunEvals',5000,'MaxIter',2000,'Display','off');
best_res=inf; best_p=p0;
for k=1:10
    ps=p0+0.1*randn(size(p0)).*abs(p0); ps=max(lb,min(ub,ps));
    try [pp,res]=lsqcurvefit(@Fy_fcn,ps,INPUT,FY_m,lb,ub,opts);
        if res<best_res, best_res=res; best_p=pp; end
    catch, end
end
p_fy=best_p; FY_pred=Fy_fcn(p_fy,INPUT);
R2_fy=1-sum((FY_m-FY_pred).^2)/sum((FY_m-mean(FY_m)).^2);
RMSE_fy=sqrt(mean((FY_m-FY_pred).^2));
fprintf('  Fy: R2=%.4f  RMSE=%.0f N\n', R2_fy, RMSE_fy);

% 设置全局 Fy 参数供 Mz 使用
PCY1=p_fy(1);PDY1=p_fy(2);PDY2=p_fy(3);PDY3=p_fy(4);
PEY1=p_fy(5);PEY2=p_fy(6);PEY3=p_fy(7);PEY4=p_fy(8);
PKY1=p_fy(9);PKY2=p_fy(10);PKY3=p_fy(11);
PHY1=p_fy(12);PHY2=p_fy(13);PHY3=p_fy(14);
PVY1=p_fy(15);PVY2=p_fy(16);PVY3=p_fy(17);PVY4=p_fy(18);

% Mz 拟合
B0=[5,-2,0,0,0,20,0,1.5,-0.1,0,10,-100,0.01,0,0.1,0,-1.6,-0.36,0,0.2,0,0.005,0,0.005,-0.08];
lb_mz=[-10,-10,-5,-5,-5,-50,-50,0.5,-5,-5,-20,-200,-5,-5,-5,-5,-10,-10,-3,-3,-3,-0.5,-0.5,-0.5,-5];
ub_mz=[10,10,5,5,5,5000,50,10,5,5,200,200,5,5,50,50,10,10,3,3,3,0.5,0.5,0.5,5];
best_mz_res=inf; best_mz=B0;
for k=1:5
    bs=B0+0.1*randn(size(B0)).*abs(B0); bs=max(lb_mz,min(ub_mz,bs));
    try [bb,res]=lsqcurvefit(@Mz_fcn,bs,INPUT,MZ_m,lb_mz,ub_mz,opts);
        if res<best_mz_res, best_mz_res=res; best_mz=bb; end
    catch, end
end
p_mz=best_mz; MZ_pred=Mz_fcn(p_mz,INPUT);
R2_mz=1-sum((MZ_m-MZ_pred).^2)/sum((MZ_m-mean(MZ_m)).^2);
RMSE_mz=sqrt(mean((MZ_m-MZ_pred).^2));
fprintf('  Mz: R2=%.4f  RMSE=%.2f Nm\n', R2_mz, RMSE_mz);

%% ═══════════ 4. 保存拟合结果 ═══════════
if ~exist('拟合结果','dir'), mkdir('拟合结果'); end
fit.p_fy=p_fy; fit.p_mz=p_mz; fit.FZ0=FZ0;
fit.R2_fy=R2_fy; fit.RMSE_fy=RMSE_fy;
fit.R2_mz=R2_mz; fit.RMSE_mz=RMSE_mz;
save('拟合结果\fit_43075_LCO.mat','fit');
coeff={'PCY1','PDY1','PDY2','PDY3','PEY1','PEY2','PEY3','PEY4',...
    'PKY1','PKY2','PKY3','PHY1','PHY2','PHY3','PVY1','PVY2','PVY3','PVY4'};
fid=fopen('拟合结果\43075_LCO_Fy_coefficients.csv','w');
fprintf(fid,'Coefficient,Value\n');
for i=1:18, fprintf(fid,'%s,%.6f\n',coeff{i},p_fy(i)); end
fclose(fid);

%% ═══════════ 5. 分气压拟合 (12psi vs 10.5psi, IA≈0°) ═══════════
fprintf('\nPer-pressure fits:\n');
p_masks={[80 86],[68 76]}; p_names={'12 psi','10.5 psi'};
p_colors={[0.84 0.33 0.10],[0.00 0.45 0.74]};
per_fit=cell(1,2);
for pi=1:2
    m=P_r>p_masks{pi}(1)&P_r<p_masks{pi}(2)&abs(IA_r)<0.5;
    S=SA_r(m);F=FZ_r(m);Y=FY_r(m);
    Sg=round(S*2)/2;Fg=round(F/50)*50;
    [~,~,ic_]=unique([Sg,Fg],'rows');nG_=max(ic_);
    Sm=accumarray(ic_,S,[],@mean);Fm=accumarray(ic_,F,[],@mean);
    Ym=accumarray(ic_,Y,[],@mean);
    best_res=inf;bp=p0;
    for k=1:5
        ps=p0+0.1*randn(size(p0)).*abs(p0);ps=max(lb,min(ub,ps));
        try [pp,res]=lsqcurvefit(@Fy_fcn,ps,[Sm,Fm,zeros(nG_,1)],Ym,lb,ub,opts);
            if res<best_res,best_res=res;bp=pp;end
        catch,end
    end
    per_fit{pi}=bp;
    YP=Fy_fcn(bp,[Sm,Fm,zeros(nG_,1)]);
    fprintf('  %s: R2=%.4f\n',p_names{pi},1-sum((Ym-YP).^2)/sum((Ym-mean(Ym)).^2));
end

%% ═══════════ 6. 生成三张最终图 ═══════════
if ~exist('对比图','dir'), mkdir('对比图'); end
SA_model=linspace(-15,15,300)';
FZ_scan=linspace(200,1300,150)';

% --- Fig1: 3D Surface ---
SA_g=linspace(-15,15,80)';FZ_g=linspace(200,1300,65)';
[SA_m,FZ_m]=meshgrid(SA_g,FZ_g);
p=per_fit{1};
inp=[SA_m(:),FZ_m(:),zeros(size(SA_m(:)))];
FY_s=reshape(Fy_fcn(p,inp),size(SA_m));
inp2=[SA_m(:),FZ_m(:),2*ones(size(SA_m(:)))];
FY2=reshape(Fy_fcn(p,inp2),size(SA_m));

figure('Position',[80 80 1500 900],'Color','w');
surf(SA_m,FZ_m,FY_s,'EdgeColor','none','FaceAlpha',0.88);hold on;
colormap(gca,turbo);colorbar;ylabel(colorbar,'F_y [N]');
mesh(SA_m(1:3:end,1:3:end),FZ_m(1:3:end,1:3:end),FY2(1:3:end,1:3:end),...
    'EdgeColor',[0.9 0.4 0.1],'FaceColor','none','LineWidth',1);
light('Position',[1 0.6 1],'Style','infinite');light('Position',[-0.5 -0.3 0.6],'Style','infinite');
lighting gouraud;material([0.3 0.7 0.2]);
xlabel('Slip Angle [deg]');ylabel('F_z [N]');zlabel('F_y [N]');
title({'\bfHoosier 43075 R20 - Pacejka MF5.2 Model';...
    'F_y(\alpha,F_z): IA=0\circ surface + IA=2\circ wireframe overlay'},'FontSize',16);
legend('IA=0\circ','IA=2\circ','Location','northeast');
set(gca,'FontSize',12,'LineWidth',1);view(140,28);grid on;
saveas(gcf,'对比图\R20_fig1_3D_model.png');
savefig(gcf,'对比图\R20_fig1_3D_model.fig');

% --- Fig2: Camber Insensitivity ---
IA_vals=[0 2 4];IA_colors={[0.84 0.33 0.10],[0.00 0.45 0.74],[0.47 0.67 0.19]};
figure('Position',[50 100 1600 500],'Color','w');
for fzi=1:3
    subplot(1,3,fzi);hold on;grid on;
    fz_c=[400 700 1000];fz_c=fz_c(fzi);
    for iai=1:3
        fy=Fy_fcn(p,[SA_model,fz_c*ones(size(SA_model)),IA_vals(iai)*ones(size(SA_model))]);
        plot(SA_model,fy,'-','LineWidth',2.5,'Color',IA_colors{iai});
    end
    xlabel('Slip Angle [deg]');ylabel('F_y [N]');
    title(sprintf('F_z = %d N',fz_c),'FontSize',14,'FontWeight','bold');
    if fzi==3,legend('IA=0\circ','IA=2\circ','IA=4\circ','Location','se');end
    set(gca,'FontSize',12);xlim([-15 15]);
end
sgtitle({'\bfHoosier 43075 R20 - Camber Sensitivity @ 12 psi';...
    'Three camber curves nearly overlap \rightarrow camber-insensitive tire'},'FontSize',16);
saveas(gcf,'对比图\R20_fig2_camber_insensitive.png');
savefig(gcf,'对比图\R20_fig2_camber_insensitive.fig');

% --- Fig3: Pressure Effect ---
mu12=zeros(size(FZ_scan));mu10=zeros(size(FZ_scan));
cs12=zeros(size(FZ_scan));cs10=zeros(size(FZ_scan));
for i=1:length(FZ_scan)
    sa_s=linspace(0,15,100)';
    fy=Fy_fcn(per_fit{1},[sa_s,FZ_scan(i)*ones(size(sa_s)),zeros(size(sa_s))]);
    mu12(i)=max(abs(fy))/FZ_scan(i);
    fy=Fy_fcn(per_fit{2},[sa_s,FZ_scan(i)*ones(size(sa_s)),zeros(size(sa_s))]);
    mu10(i)=max(abs(fy))/FZ_scan(i);
    fx0=Fy_fcn(per_fit{1},[0,FZ_scan(i),0]);fxE=Fy_fcn(per_fit{1},[0.05,FZ_scan(i),0]);
    cs12(i)=abs(fxE-fx0)/0.05/1000;
    fx0=Fy_fcn(per_fit{2},[0,FZ_scan(i),0]);fxE=Fy_fcn(per_fit{2},[0.05,FZ_scan(i),0]);
    cs10(i)=abs(fxE-fx0)/0.05/1000;
end
figure('Position',[100 100 1100 700],'Color','w');
subplot(2,2,1);hold on;grid on;
plot(FZ_scan/1000,mu12,'-','LineWidth',3,'Color',p_colors{1});
plot(FZ_scan/1000,mu10,'--','LineWidth',3,'Color',p_colors{2});
xlabel('F_z [kN]');ylabel('\mu_y');title('Peak Friction');
legend(p_names,'Location','best','FontSize',11);set(gca,'FontSize',12);

subplot(2,2,2);hold on;grid on;
plot(FZ_scan/1000,cs12,'-','LineWidth',3,'Color',p_colors{1});
plot(FZ_scan/1000,cs10,'--','LineWidth',3,'Color',p_colors{2});
xlabel('F_z [kN]');ylabel('CS [kN/deg]');title('Cornering Stiffness');
legend(p_names,'Location','best','FontSize',11);set(gca,'FontSize',12);

subplot(2,2,[3 4]);hold on;grid on;
fy12=Fy_fcn(per_fit{1},[SA_model,700*ones(size(SA_model)),zeros(size(SA_model))]);
fy10=Fy_fcn(per_fit{2},[SA_model,700*ones(size(SA_model)),zeros(size(SA_model))]);
plot(SA_model,fy12,'-','LineWidth',3,'Color',p_colors{1});
plot(SA_model,fy10,'--','LineWidth',3,'Color',p_colors{2});
x2=[SA_model;flipud(SA_model)];
fill(x2,[fy12;flipud(fy10)],[0.7 0.7 0.7],'FaceAlpha',0.25,'EdgeColor','none');
xlabel('Slip Angle [deg]');ylabel('F_y [N]');
title('F_y(\alpha) @ F_z = 700 N, IA = 0\circ');
legend([p_names,{'Diff'}],'Location','se','FontSize',11);set(gca,'FontSize',12);
sgtitle('\bfHoosier 43075 R20 - Pressure Effect: 12 vs 10.5 psi','FontSize',16);
saveas(gcf,'对比图\R20_fig3_pressure.png');
savefig(gcf,'对比图\R20_fig3_pressure.fig');

close all;
fprintf('\n===== Done =====\n');
fprintf('Results: 拟合结果/ | Figures: 对比图/\n');

%% ═══════════ 本地函数: MF5.2 ═══════════
function FY = Fy_fcn(A,X)
    global FZ0
    global LFZO LCY LMUY LEY LKY LHY LVY LGAY
    
    ALPHA = X(:,1)*pi/180;
    FZ = abs(X(:,2));
    GAMMA = X(:,3)*pi/180;
    GAMMAY = GAMMA .* LGAY;
    FZ0PR = FZ0 .* LFZO;
    DFZ = (FZ-FZ0PR) ./ FZ0PR;
    
    PCY1=A(1);PDY1=A(2);PDY2=A(3);PDY3=A(4);
    PEY1=A(5);PEY2=A(6);PEY3=A(7);PEY4=A(8);
    PKY1=A(9);PKY2=A(10);PKY3=A(11);
    PHY1=A(12);PHY2=A(13);PHY3=A(14);
    PVY1=A(15);PVY2=A(16);PVY3=A(17);PVY4=A(18);
    
    SHY = (PHY1+PHY2.*DFZ).*LHY + PHY3.*GAMMAY;
    ALPHAY = ALPHA+SHY;
    CY = PCY1.*LCY;
    MUY = (PDY1+PDY2.*DFZ).*(1.0-PDY3.*GAMMAY.^2).*LMUY;
    DY = MUY.*FZ;
    KY = PKY1.*FZ0.*sin(2.0.*atan(FZ./(PKY2.*FZ0.*LFZO))).*(1.0-PKY3.*abs(GAMMAY)).*LFZO.*LKY;
    BY = KY./(CY.*DY);
    EY = (PEY1+PEY2.*DFZ).*(1.0-(PEY3+PEY4.*GAMMAY).*sign(ALPHAY)).*LEY;
    EY = max(min(EY, 0.999), -0.999);
    SVY = FZ.*((PVY1+PVY2.*DFZ).*LVY+(PVY3+PVY4.*DFZ).*GAMMAY).*LMUY;
    FY0 = DY.*sin(CY.*atan(BY.*ALPHAY-EY.*(BY.*ALPHAY-atan(BY.*ALPHAY))))+SVY;
    FY = FY0;
end

function MZ = Mz_fcn(B,X)
    global FZ0 R0
    global PCY1 PDY1 PDY2 PDY3 PEY1 PEY2 PEY3 PEY4 ...
           PKY1 PKY2 PKY3 PHY1 PHY2 PHY3 PVY1 PVY2 PVY3 PVY4
    global LFZO LKY LHY LVY LCY LMUY LEY LGAY LGAZ LTR LRES
    
    ALPHA = X(:,1)*pi/180;
    FZ = abs(X(:,2));
    GAMMA = X(:,3)*pi/180;
    GAMMAY = GAMMA.*LGAY; GAMMAZ = GAMMA.*LGAZ;
    FZ0PR = FZ0.*LFZO;
    DFZ = (FZ-FZ0PR)./FZ0PR;
    
    QBZ1=B(1);QBZ2=B(2);QBZ3=B(3);QBZ4=B(4);QBZ5=B(5);
    QBZ9=B(6);QBZ10=B(7);QCZ1=B(8);
    QDZ1=B(9);QDZ2=B(10);QDZ3=B(11);QDZ4=B(12);
    QDZ6=B(13);QDZ7=B(14);QDZ8=B(15);QDZ9=B(16);
    QEZ1=B(17);QEZ2=B(18);QEZ3=B(19);QEZ4=B(20);QEZ5=B(21);
    QHZ1=B(22);QHZ2=B(23);QHZ3=B(24);QHZ4=B(25);
    
    SHY=(PHY1+PHY2.*DFZ).*LHY+PHY3.*GAMMAY;
    SVY=FZ.*((PVY1+PVY2.*DFZ).*LVY+(PVY3+PVY4.*DFZ).*GAMMAY).*LMUY;
    ALPHAY=ALPHA+SHY;
    SHT=QHZ1+QHZ2.*DFZ+(QHZ3+QHZ4.*DFZ).*GAMMAZ;
    ALPHAT=ALPHA+SHT;
    KY=PKY1.*FZ0.*sin(2.0.*atan(FZ./(PKY2.*FZ0.*LFZO))).*(1.0-PKY3.*abs(GAMMAY)).*LFZO.*LKY;
    SHF=SHY+SVY./KY; ALPHAR=ALPHA+SHF;
    BT=(QBZ1+QBZ2.*DFZ+QBZ3.*DFZ.^2).*(1.0+QBZ4.*GAMMAZ+QBZ5.*abs(GAMMAZ)).*LKY./LMUY;
    CT=QCZ1;
    DT=FZ.*(QDZ1+QDZ2.*DFZ).*(1.0+QDZ3.*GAMMAZ+QDZ4.*GAMMAZ.^2).*(R0./FZ0).*LTR;
    ET=(QEZ1+QEZ2.*DFZ+QEZ3.*DFZ.^2).*(1.0+(QEZ4+QEZ5.*GAMMAZ).*(2/pi).*atan(BT.*CT.*ALPHAT));
    ET=max(min(ET,0.999),-0.999);
    CY=PCY1.*LCY;
    MUY=(PDY1+PDY2.*DFZ).*(1.0-PDY3.*GAMMAY.^2).*LMUY;
    DY=MUY.*FZ; BY=KY./(CY.*DY);
    BR=QBZ9.*LKY./LMUY+QBZ10.*BY.*CY;
    DR=FZ.*((QDZ6+QDZ7.*DFZ).*LRES+(QDZ8+QDZ9.*DFZ).*GAMMAZ).*R0.*LMUY;
    TRAIL=DT.*cos(CT.*atan(BT.*ALPHAT-ET.*(BT.*ALPHAT-atan(BT.*ALPHAT)))).*cos(ALPHA);
    MZR=DR.*cos(atan(BR.*ALPHAR)).*cos(ALPHA);
    EY=(PEY1+PEY2.*DFZ).*(1.0-(PEY3+PEY4.*GAMMAY).*sign(ALPHAY)).*LEY;
    SVY=FZ.*((PVY1+PVY2.*DFZ).*LVY+(PVY3+PVY4.*DFZ).*GAMMAY).*LMUY;
    FY0=DY.*sin(CY.*atan(BY.*ALPHAY-EY.*(BY.*ALPHAY-atan(BY.*ALPHAY))))+SVY;
    MZ0=-TRAIL.*FY0+MZR;
    MZ=MZ0;
end
