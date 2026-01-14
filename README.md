<!--
<img src="https://drive.google.com/uc?id=1fgYuG7jpnekZrkoL_PdVUnSiUFBFX-vI" alt="Logo" width="150" style="float: left; margin-right: 10px;">
-->

<img src="https://drive.google.com/uc?id=1szqLViKqTX5C1XF8uV7HbIst0i6Xvv7g" alt="Logo" width="300">


# Interior Native Habitat Indicator for Alberta
> Version 1.0 2026-01-28

![Maintenance](https://img.shields.io/badge/Status-Maintenance-green)
![Languages](https://img.shields.io/badge/Languages-R%20%7C%20Python-blue)
![Programs](https://img.shields.io/badge/Programs-R%20%7C%20ArcPro-blue)


## Introduction

Alberta Environment and Protected Areas, in partnership with the Alberta Biodiversity Monitoring Institute (ABMI), developed the Interior Native Habitat indicator to support biodiversity conservation and land-use management. ‘Interior Native Habitat’ is defined as an area that is outside the sphere of influence of anthropogenic disturbance. The Interior Native Habitat indicator quantifies one facet of biodiversity loss by tracking the amount of area that is not impacted by the edge effects caused by human footprints such as settlement, agriculture, resource extraction, and transportation.

We calculate Interior Native Habitat using three buffer distances:
- 50m buffer that is weighted based on the feature type, width for linear features, and age of harvest area.
- 200m buffer that is weighted based on the feature type, width for linear features, and age of harvest area. This is the buffer distance used in the indicator presented on [GeoDiscover Alberta](https://open.alberta.ca/publications/interior-habitat-indicator-for-alberta)
- 500m buffer that is not weighted based on the feature type or age of harvest area.

## Repository Contents

This repository contains the R code (**1_code/**) required for generating the three buffer distances.

## Acknowledgements

We would like to acknowledge that this indicator was developed by the dedicated staff at ABMI and Alberta Environment and Protected Areas. This work would not be possible without your guidance and expertise.

## Support

For any questions regarding the scripts presented in this repository, GeoDiscover product, technical documentation, or about other applications of this indicator, please contact Brandon Allen (ABMI Senior Terrestrial Ecologist) at brandon.allen@ualberta. 

