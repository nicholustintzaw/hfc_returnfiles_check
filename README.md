# hfc_returnfiles_check

## Purpose
### Perform quick check on the hfc outputs follow-up check files ruturn from the field teams

*checking perform the following sheets from hfc outputs files and bc check result files*
1. hfc outputs - *outliers*
2. hfc outputs - *constraints*
3. hfc outputs - *other specify* 
4. bc outputs sheet

*field team need to provide their comments on each sheet by adding **two variable** in each output sheet*;
1. comment - explain the follow-up check answer from the respective enumerator or team leader
2. correctvalue - if enumerators provided the correct value to perform data correction, pelase mentione in this variable

*check functions*
1. **combine** all return files
2. check **missing value** in either comment variable or correctvalue variable
3. **zero value check** - based on the survey data nature, this help to identify the enumreator provided correctvalue were "zero" cases
4. **non numeric correct value** - identify the non-numeric obdservation from enumerator reponse value which require counter check with survey program to replace with correct coding value
5. **duplicates** - identify the duplciated observation in hfc follow-up check return files 
6. **illogical answer** - the enumerator provided correctvalue which were not likely to be correct value
7. **not report yet** - to identify the missing observation (by submission date) which still need to report by the field team
8. **data correction** - keep only the obaservation to process for data correction


**in this dofile**
user neeed to adjust the *directory setting* based on the respective project's work-flow
this dofiles was design to capture all hfc return files from each type of hfc output folder and provide report on each cehcking issue type in one folder
