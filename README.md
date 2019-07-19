<h1>particle-detection-algorithm</h1>
This is a algorithm according to a non-maximum suppression algorithmn proposed by Sbalzerini et al 2005</p>

<h2>SYNTAX:</h2>
[selRegion, numbReg] = featureDetectionSb(img, w, pth, radius, show_figure)</p>

<h2>DESCRIPTION:</h2>

Input: img = reference image, where to look for feature points <br>
       w = radius of the mask / filter <br>
       pth = threshold for intensity based detemination of intensity maxima <br>
       radius = to determin the area for computing the intensity value of each ROI by averaging intensity values within this area <br>
       show_figures = ahow control figures (1 = yes, 0 = no)<br>
Output: selRegion = struct containing information about the ROIs
