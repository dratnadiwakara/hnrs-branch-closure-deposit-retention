|                                         |model 1                     |model 2                     |model 3            |model 4           |
|:----------------------------------------|:---------------------------|:---------------------------|:------------------|:-----------------|
|                                         |frac_branches ~ count       |frac_branches ~ dep         |share_deps ~ count |share_deps ~ dep  |
|Dependent Var.:                          |fraction_of_branches_closed |fraction_of_branches_closed |share_deps_closed  |share_deps_closed |
|                                         |                            |                            |                   |                  |
|frac_apps_zip_count                      |-0.0084*                    |                            |-0.0030            |                  |
|                                         |(0.0046)                    |                            |(0.0034)           |                  |
|frac_apps_zip_count x perc_hh_wMobileSub |0.0182**                    |                            |0.0130*            |                  |
|                                         |(0.0091)                    |                            |(0.0068)           |                  |
|frac_apps_zip_dep                        |                            |-0.0103**                   |                   |-0.0038           |
|                                         |                            |(0.0040)                    |                   |(0.0031)          |
|frac_apps_zip_dep x perc_hh_wMobileSub   |                            |0.0207***                   |                   |0.0112*           |
|                                         |                            |(0.0079)                    |                   |(0.0063)          |
|Mean(LHS)                                |0.024                       |0.024                       |0.013              |0.013             |
|SD(frac_apps)                            |0.233                       |0.253                       |0.233              |0.253             |
|Joint F (tech)                           |2.07                        |3.65                        |2.58               |1.65              |
|Fixed-Effects:                           |--------------------------- |--------------------------- |-----------------  |----------------- |
|zip                                      |Yes                         |Yes                         |Yes                |Yes               |
|county_yr                                |Yes                         |Yes                         |Yes                |Yes               |
|________________________________________ |___________________________ |___________________________ |_________________  |_________________ |
|S.E.: Clustered                          |by: zip                     |by: zip                     |by: zip            |by: zip           |
|Observations                             |70,223                      |70,223                      |70,223             |70,223            |
|R2                                       |0.23796                     |0.23800                     |0.23437            |0.23434           |
|Within R2                                |7.36e-5                     |0.00013                     |9.28e-5            |6.11e-5           |
