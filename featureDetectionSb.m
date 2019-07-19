% Detects the ROIs based  on centroids
% Algorithm published by Sbalzerini, 2005
%
% SYNTAX:
% [selRegion, numbReg] = featureDetectionSb(img, w, pth, radius,
% show_figure)
% 
% DESCRIPTION
%
% Input: img = reference image, where to look for feature points
%        w = radius of the mask / filter
%        pth = threshold for intensity based detemination of intensity maxima
%        radius = to determin the area for computing the intensity value of each ROI by averaging intensity values within this ares
%        show_figures = ahow control figures (1 = yes, 0 = no)
% Output: selRegion = struct containing information about the ROIs

function [selRegion, numbReg] = featureDetectionSb(img, w, pth, radius, show_figures)
% Correlation length of camera noise (usu. set to unity)
lambdan = 1;

% Normalize image:
img = double(img);
img = (img-min(img(:)))/(max(img(:))-min(img(:)));

% some often used quantities
idx = -w:1:w;     % index vector
dm = 2*w+1;         % diameter
im = repmat(idx',1,dm);
jm = repmat(idx,dm,1);
imjm2 = im.^2+jm.^2;
siz = size(img);   % image size

%======================================================================
% STEP 1: Image restoration
%======================================================================

% build kernel K for background extraction and noise removal
% (eq. [4])
B = sum(exp(-(idx.^2/(4*lambdan^2))));
B = B^2;
K0 = 1/B*sum(exp(-(idx.^2/(2*lambdan^2))))^2-(B/(dm^2));
K = (exp(-(imjm2/(4*lambdan^2)))/B-(1/(dm^2)))/K0;

% apply convolution filter
filtered = conv2(img,K,'same');
filtered(filtered<0)= 0;

clearvars B K0 K lambdan

%======================================================================
% STEP 2: Locating particles
%======================================================================

% remove border values in filtered image:
filtered = imclearborder(filtered);
% determining upper pth-th percentile of intensity values
pth = 0.01*pth;

[m,n]=size(filtered);

[cnts,bins] = imhist(filtered(1+w:m-w ,1+w:n-w));
l = length(cnts);
k = 1;
while sum(cnts(l-k:l))/sum(cnts) < pth,
    k = k + 1;
end;
thresh = bins(l-k+1);

clearvars l k m n pth

% generate circular mask of radius w

mask = zeros(dm,dm);
mask(imjm2 <= w*w) = 1;

% identify individual particles as local maxima in a
% w-neighborhood that are larger than thresh
dil = imdilate(filtered,mask);
[Rp,Cp] = find((dil-filtered)==0);
temp_r=Rp;
temp_c=Cp;
count=1;
clearvars Rp Cp

for cand=1:size(temp_r,1)
    if temp_r(cand,1)>w && temp_c(cand,1)>w && temp_r(cand,1)<size(img,2)-w && temp_c(cand,1)<size(img,1)-w
        Rp(count,1)=temp_r(cand,1);
        Cp(count,1)=temp_c(cand,1);
        count=count+1;
    end
end

V = find(filtered(sub2ind(siz,Rp,Cp))>thresh);
R = Rp(V);
C = Cp(V);
clearvars Rp Cp thresh temp_r temp_c count cand cnts

regionNb = length(R);

%======================================================================
% STEP 2:Refinement and Discrimination
%======================================================================
%new mask, according to radius
%
idx = -radius:1:radius;     % index vector
dm = 2*radius+1;         % diameter
im = repmat(idx',1,dm);
jm = repmat(idx,dm,1);
imjm2 = im.^2+jm.^2;
mask = zeros(dm,dm);
mask(imjm2 <= radius*radius) = 1;

parameter.img = img;
parameter.mask = mask;
parameter.idx = jm;
parameter.idy = im;
parameter.radius = radius;
parameter.ij2 = imjm2;
regionProperties(regionNb,1).Centroid = 1;
regionProperties(regionNb,1).PixelIdxList = 1;
moments = zeros(regionNb,2);

for region=1:regionNb
    %--refinement------------------------------------------------
    parameter.centerX=C(region,1);
    parameter.centerY=R(region,1);
    RowBorder = R(region,1)-radius;
    ColBorder = C(region,1)-radius;
    RowBorder2 = R(region,1)+radius;
    ColBorder2 = C(region,1)+radius;
    if RowBorder <= 0 
       RowBorder = 1;
    end
    
    if ColBorder <= 0
       ColBorder = 1;
    end
    
    if RowBorder2 > siz(1);
       RowBorder2 = siz(1);
    end
    
    if ColBorder2 > siz(2);
       ColBorder2 = siz(2);
    end
    
    parse = size(img(RowBorder:RowBorder2,ColBorder:ColBorder2));
    area = zeros(size(mask));
    area(1:parse(1),1:parse(2)) = img(RowBorder:RowBorder2,ColBorder:ColBorder2);
    area(mask == 0) = 0;
    parameter.area = area;
    parameter.m0 = sum(sum(area));
    parameter = refinement(parameter);
    %--calculation of second-order intensity moment-------------
    parameter = m2Calc(parameter);
    %-----------------------------
    moments(region,1) = parameter.m0;
    moments(region,2) = parameter.m2;
    regionProperties(region,1).surroundInt = parameter.area;
    regionProperties(region,1).m0 = parameter.m0;
    regionProperties(region,1).Centroid(1,1)=parameter.centerX;
    regionProperties(region,1).Centroid(1,2)=parameter.centerY;
    regionProperties(region,1).area = parameter.area;
    [pxlList] = indxList(siz, parameter.centerX,parameter.centerY,radius);
    if pxlList ~= 0
        regionProperties(region,1).PixelIdxList = pxlList;
    end
end

sigm0m = 0.1*pi*radius^2;
sigm2m = 0.1*pi*radius^2;
% sigm0m = std(moments(:,1));
% sigm2m = std(moments(:,2));
discrPara.regionNb = regionNb;
discrPara.sigm0 = sigm0m;
discrPara.sigm2 = sigm2m;
discrPara.moments = moments;

selected = discrimination(discrPara);
numbReg = length(selected);

selRegion(numbReg,1).Centroid = 1;
moments2 = zeros(numbReg,2);
Csel = zeros(numbReg,1);
Rsel = zeros(numbReg,1);

for i = 1:numbReg
    selRegion(i,1).Centroid(1,1) = regionProperties(selected(i),1).Centroid(1,1);
    selRegion(i,1).Centroid(1,2) = regionProperties(selected(i),1).Centroid(1,2);
    selRegion(i,1).area = regionProperties(selected(i),1).area;
    selRegion(i,1).PixelIdxList = regionProperties(selected(i),1).PixelIdxList;
    moments2(i,1) = moments(selected(i),1);
    moments2(i,2) = moments(selected(i),2);
    % for imaging
    if show_figures == 1
        Csel(i) = selRegion(i,1).Centroid(1,1);
        Rsel (i)= selRegion(i,1).Centroid(1,2);
    end
end

%======================================================================
% STEP 4: Display
%======================================================================

if show_figures==1
    figure (1)
    title('without discrimination' +regionNb)
    imshow(img,'DisplayRange',[min(img(:)) max(img(:))])
    hold on
    scatter(C,R,5, 'filled', 'MarkerFaceColor', 'yellow')
    
    figure (2)
    title ('after particle discimination' +numbReg)
    imshow(img,'DisplayRange',[min(img(:)) max(img(:))])
    hold on
    scatter(Csel,Rsel,5, 'filled', 'MarkerFaceColor', 'red')
    
    figure (3)
    title ('merged')
    imshow(img,'DisplayRange',[min(img(:)) max(img(:))])
    hold on
    scatter(C,R,5, 'filled', 'MarkerFaceColor', 'yellow')
    hold on
    scatter(Csel,Rsel,5, 'filled', 'MarkerFaceColor', 'red') 
    
    figure (4)
    title('moments')  
    
    scatter(moments(:,1),moments(:,2))
    hold on
    scatter(moments2(:,1), moments2(:,2))
    
    xlabel('0 order intensity moment')
    ylabel('2 order intensity moment')
    
end
