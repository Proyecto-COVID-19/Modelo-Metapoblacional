%% METAPOPULATION MODEL COVID 19
% Juan D. Uma�a / Daniel Duque / Diana Erazo
clc
clear all
close all

%% City Info
ID = 'Barranquilla';
route = './Data/';
file = '/CityInfo.xlsx';
loc = [route,ID,file];
CI = readtable(loc,'ReadVariableNames',0);

city_name = CI{1,2};
city_nodes = str2double(CI{2,2});
v_nodesnames = CI{3:2+city_nodes,2};
v_nodespop = str2double(CI{3+city_nodes:2+city_nodes+city_nodes,2});
v_nodesHosp = str2double(CI{3+city_nodes+city_nodes:2+city_nodes+city_nodes+city_nodes,2});

%% City Data

file = '/MovMatrix.mat';
loc = [route,ID,file];
load(loc);

mov = {M{1},M{1}'...
    M{3}, M{3}'...
    M{5}, M{5}'...
    M{7}, M{7}'...
    M{9}, M{9}'...
    M{11},M{11}'...
    M{13},M{13}'...
    M{15},M{15}'};

City.name = city_name;

for i=1:city_nodes
    City.node(i).nodename = v_nodesnames(i);
    City.node(i).pop = v_nodespop(i);
    City.node(i).hosp = v_nodesHosp(i);
end

City.mov = mov;

file = '/CityTimeSeries.xlsx';
loc = [route,ID,file];

CityTimeSeries = readtable(loc,'ReadVariableNames',0);

City.Dates = datetime(char(CityTimeSeries{2:end,1}),'InputFormat','dd/MM/yyyy');
City.Incidence = str2double(CityTimeSeries{2:end,2});
City.Prevalence = str2double(CityTimeSeries{2:end,3});
City.DailyDeaths = str2double(CityTimeSeries{2:end,4});
City.TotDeaths = str2double(CityTimeSeries{2:end,5});

for i=1:city_nodes
    str_node = '/Node';
    str_i = num2str(i);
    str_timeseries = 'TimeSeries.xlsx';
    
    loc = [route,ID,str_node,str_i,str_timeseries];
    
    NodeTimeSeries = readtable(loc,'ReadVariableNames',0);
    
    City.node(i).Dates = datetime(char(NodeTimeSeries{2:end,1}),'InputFormat','dd/MM/yyyy');
    City.node(i).Incidence = str2double(NodeTimeSeries{2:end,2});
    City.node(i).Prevalence = str2double(NodeTimeSeries{2:end,3});
    City.node(i).DailyDeaths = str2double(NodeTimeSeries{2:end,4});
    City.node(i).TotDeaths = str2double(NodeTimeSeries{2:end,5});
    
end

%% Model Variables and Parameters
syms S... Susceptible Inividuals
    E... Exposed Individuals
    A... Asymptomatict/Undetected Individuals
    I1... Infected Individuals (Home)
    I2... Infected Individuals (Hospital)
    I3... Infected Individuals (ICU)
    R... Recovered Individuals
    D... Dead Individuals
    
v_Variables = [S E A I1 I2 I3 R D];

syms b... Transmission
    s_a... Asymptomatic transmission regulator
    s_1... I1 transmission regulator
    s_2... I2 transmission regulator
    s_3... I3 transmission regulator
    p... Probability of diagnosis
    k... Probability of symptoms development
    w... Latent period
    r_1... Complication probability
    r_2... Complication probability
    r_3... Complication probability
    l_1... Complication period
    l_2... Complication period
    l_3... Complication period
    g_a... Recovery period
    g_1... Recovery period
    g_2... Recovery period
    g_3... Recovery period
    

v_Parameters = [b s_a s_1 s_2 s_3 p k w r_1 r_2 r_3 l_1 l_2 l_3 g_1 g_2 g_3];

global v_Variables v_Parameters

%% Model Equations (No movement)
global N trans dS dE dA dI1 dI2 dI3 dR dD

N = S+E+A+I1+I2+I3+R+D;
trans = b*S*(s_a*A + s_1*I1 + s_2*I2 + s_3*I3)/(N-D);

dS = -trans;

dE = trans - (1-p)*(1-k)*E/w - p*k*E/w;

dA = (1-p)*(1-k)*E/w - r_1*A/l_1 - (1-r_1)*A/g_1;

dI1 = p*k*E/w - r_1*I1/l_1 - (1-r_1)*I1/g_1;

dI2 = r_1*I1/l_1 + r_1*A/l_1 - r_2*I2/l_2 - (1-r_2)*I2/g_2;

dI3 = r_2*I2/l_2 - r_3*I3/l_3 - (1-r_3)*I3/g_3;

dR = (1-r_1)*A/g_1 + (1-r_1)*I1/g_1 + (1-r_2)*I2/g_2 + (1-r_3)*I3/g_3;

dD = r_3*I3/l_3;

%% Fitting

% for i=1:city_nodes
%     City.node(i).beta = COVIDfitting(City.node(i));
% end

%% Initial
t = 2*365; % Number of days to simulate
shifts = 2; % Number of shifts per day
global shifts
Tshifts = t*shifts; % Total number of shifts

global daysSince
daysSince = datenum(datetime('today')) - datenum(City.node(1).Dates(1));

City.beta = zeros(length(City.node),Tshifts);
City.beta(:,1:10*shifts) = 1.5;
City.beta(:,10*shifts:daysSince*shifts) = 0.1*1.5;
City.beta(:,daysSince*shifts:Tshifts) = 0.3*1.5;
City.init = initialize([City.node.pop], length(v_Variables));


%% Simulation
[T,Y] = runfun(City.init,City.node,Tshifts,City.beta,City.mov,length(v_Variables));
City.T = T;
City.Y = Y;


%% Visualization


graphMetaPop(City)

global betah

figure()
hold on

for f=1:5
    plot(betah(f,:))
end

idx = 1:length(Y);
idxq = linspace(min(idx),max(idx),t);
Ynew = interp1(idx,Y,idxq);

idx = 1:length(betah);
idxq = linspace(min(idx),max(idx),t);
betahnew = interp1(idx,betah',idxq);

