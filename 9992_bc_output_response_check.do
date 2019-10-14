/*******************************************************************************

// 	Task:			Check all the field team response answer to HFC output files
// 	Author: 		
// 	Last update: 		Sept 21 2019

*******************************************************************************/

// Settings for stata
pause on
clear all
clear mata
set more off
set scrollbufsize 100000
set mem 100m
set matsize 11000
set maxvar 32767
set excelxlsxlargefile on

********************************************************************************
*  ADJUST GLOBALS
local user = c(username)

di "`user'"

// Nicholus
if "`user'" == "nicholustintzaw" {
		global root		 			"/Users/nicholustintzaw/Box Sync/IPA_MMR_Projects/07 Microfinance Plus"	
}

global BL_HFC		"$root/07_Questionnaires&Data/0_Baseline - HFC" 
global BL_data		"$BL_HFC/05_data/02_survey/02_CTO_data"
global BL_HFC		"$root/07_Questionnaires&Data/0_Baseline - HFC" 
		

*******************************************************************************/
********************************************************************************
********************************** HH SURVEY ***********************************
********************************************************************************
*******************************************************************************/

local hhassets	a1_n a2_n a3_n a4_n a5_n a6_n a7_n a8_n a9_n a10_n a11_n a12_n ///
				a13_n a14_n a15_n a16_n a17_n a18_n a19_n a20_n a21_n a22_n a23_n ///
				a24_n a25_n a26_n a27_n

********************************************************************************
***** BACKCHECK OUTPUT CHECK *****
********************************************************************************

** Import oroginal bc file **
import delimited using "$BL_HFC/04_checks/02_outputs/backcheck.csv", clear
tempfile bcmaster
save `bcmaster', replace
clear


** BC Results - Import **

local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/00_bc_hh/" files "backcheck*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	import excel using "$BL_HFC/04_checks/03_outputs_check/00_bc_hh/`file'",firstrow case(lower) allstring clear
	gen source = "`file'"
	append using `bc'
	save `bc', replace
}

* drop missing observation *
drop if	mi(partid) & mi(enum_id) & mi(backcheck_id) & ///
		mi(type) & mi(variable) & mi(survey) & mi(back_check) & mi(correctvalue)

* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace

				

** 0: hh assets answer zero **
gen newvalue_zero = .m
foreach var in local `hhassets' {
	replace newvalue_zero = 1 if variable == "`var'" &  correctvalue == "0"
	
}

count if newvalue_zero == 1

if `r(N)' > 0 {
	preserve
	keep if newvalue_zero == 1
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("0_hhassets") firstrow(varlabels) sheetreplace
	restore
}

** 0: missing answer **
count if mi(correctvalue) & mi(comment)

if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: nun numeric answer **
gen correctvalue_num = real(correctvalue)
order correctvalue_num,after(correctvalue)

count if !mi(correctvalue) & mi(correctvalue_num)
 
if `r(N)' > 0 {
	preserve 
	keep if !mi(correctvalue) & mi(correctvalue_num)
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("1_nonnumeric") firstrow(varlabels) sheetreplace
	restore
}		


** 2: illogical answer **
** survey != bc != correctvalue **

count if !mi(correctvalue) & correctvalue != survey & correctvalue != back_check
 
if `r(N)' > 0 {
	preserve
	keep if !mi(correctvalue) & correctvalue != survey & correctvalue != back_check
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("2_illogical") firstrow(varlabels) sheetreplace
	restore
}		


** 3: duplicated answer **
sort partid variable
order partid, before(variable)

duplicates tag partid variable, gen(dup_ans)
tab dup_ans, m

duplicates tag partid variable comment, gen(dup_ans_all)
tab dup_ans_all, m

count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("3_duplicate") firstrow(varlabels) sheetreplace
	restore
}		


duplicates drop partid variable, force

** Merge with original BC check result output **
** prepare to merge **
destring partid enum_id backcheck_id type village_id, replace
drop submissiondate bc_submissiondate


merge 1:1 partid variable using `bcmaster'

foreach var of varlist submissiondate bc_submissiondate {
	gen `var'_d = clock(`var', "DMYhms")
	format `var'_d %tc
	order `var'_d, after(`var')
	drop `var'
	rename `var'_d `var'
	
	gen `var'2 = dofc(`var')
	format `var'2 %td
	order `var'2, after(`var')
}


** 4: don't found in original bc output **
count if _merge == 1

if `r(N)' > 0 {
	preserve
	keep if _merge == 1
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("4_masterbc_no") firstrow(varlabels) sheetreplace
	restore
}


** 5: haven't included yet in report answer **
count if _merge == 2 & bc_submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & bc_submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("5_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 6: data correction **
keep if _merge == 3
drop _merge


drop if mi(correctvalue) & mi(comment)
drop if !mi(correctvalue) & mi(correctvalue_num)
drop if !mi(correctvalue) & correctvalue != survey & correctvalue != back_check

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/00_bc_hh_result.xlsx", ///
						sheet("6_datacorrection") firstrow(varlabels) sheetreplace
	restore
}

clear


********************************************************************************
***** HFC: OUTLIER OUTPUT CHECK *****
********************************************************************************

** Import oroginal outlier file **
import excel using "$BL_HFC/04_checks/02_outputs/output.xlsx", sheet("11. outliers") firstrow clear

tempfile outliermaster
save `outliermaster', replace
clear


** HFC Results Outlier - Import **

local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/" files "output*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	import excel using "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/`file'", sheet("11. outliers") firstrow case(lower) allstring clear
	gen source = "`file'"
	append using `bc'
	save `bc', replace
}

** drop missing observation **
drop if mi(partid) & mi(variable) & mi(value) & mi(correctvalue) & mi(comment)


* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace


** 0: hh assets answer zero **
gen newvalue_zero = .m
foreach var in local `hhassets' {
	replace newvalue_zero = 1 if variable == "`var'" &  correctvalue == "0"
	
}

count if newvalue_zero == 1

if `r(N)' > 0 {
	preserve
	keep if newvalue_zero == 1
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("0_hhassets") firstrow(varlabels) sheetreplace
	restore
}

** 0: missing answer **
replace correctvalue = "" if correctvalue == " "

count if mi(correctvalue) & mi(comment)
if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: nun numeric answer **
gen correctvalue_num = real(correctvalue)
order correctvalue_num,after(correctvalue)

count if !mi(correctvalue) & mi(correctvalue_num)
 
if `r(N)' > 0 {
	preserve 
	keep if !mi(correctvalue) & mi(correctvalue_num)
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("1_nonnumeric") firstrow(varlabels) sheetreplace
	restore
}		


** 2: illogical answer **
** correctvalue > survey **

gen value_num = real(value)
order value_num,after(value)

count if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
 
if `r(N)' > 0 {
	preserve
	keep if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("2_illogical") firstrow(varlabels) sheetreplace
	restore
}		


** 3: duplicated answer **
sort partid variable
order partid, before(variable) 

duplicates tag partid variable, gen(dup_ans)
tab dup_ans, m

duplicates tag partid variable comment, gen(dup_ans_all)
tab dup_ans_all, m


count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("3_duplicate") firstrow(varlabels) sheetreplace
	restore
}		

duplicates drop partid variable, force

** Merge with original HFC check outlier output **
** prepare to merge **
drop scto_link // un-necessary var
destring partid enum_id, replace
tostring partid, replace

drop submissiondate


merge 1:1 partid variable using `outliermaster'

gen submissiondate2 = dofc(submissiondate)
format submissiondate2 %td


** 4: haven't included yet in report answer **
count if _merge == 2 & submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("4_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 5: data correction **
keep if _merge == 3
drop _merge

drop if mi(correctvalue) & mi(comment)
drop if !mi(correctvalue) & mi(correctvalue_num)
drop if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/01_hfc_outlier_result.xlsx", ///
						sheet("5_datacorrection") firstrow(varlabels) sheetreplace
	restore
}


clear


********************************************************************************
***** HFC: CONSTRAINTS OUTPUT CHECK *****
********************************************************************************

** Import oroginal outlier file **
import excel using "$BL_HFC/04_checks/02_outputs/output.xlsx", sheet("8. constraints") firstrow clear

tempfile constmaster
save `constmaster', replace
clear


** HFC Results Outlier - Import **

local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/" files "output*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	import excel using "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/`file'", sheet("8. constraints") firstrow case(lower) allstring clear
	gen source = "`file'"
	append using `bc'
	save `bc', replace
}

** drop missing observation **
drop if mi(partid) & mi(variable) & mi(value) & mi(correctvalue) & mi(comment)


* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace


** 0: hh assets answer zero **
gen newvalue_zero = .m
foreach var in local `hhassets' {
	replace newvalue_zero = 1 if variable == "`var'" &  correctvalue == "0"
	
}

count if newvalue_zero == 1

if `r(N)' > 0 {
	preserve
	keep if newvalue_zero == 1
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("0_hhassets") firstrow(varlabels) sheetreplace
	restore
}

** 0: missing answer **
replace correctvalue = "" if correctvalue == " "

count if mi(correctvalue) & mi(comment)
if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: nun numeric answer **
gen correctvalue_num = real(correctvalue)
order correctvalue_num,after(correctvalue)

count if !mi(correctvalue) & mi(correctvalue_num)
 
if `r(N)' > 0 {
	preserve 
	keep if !mi(correctvalue) & mi(correctvalue_num)
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("1_nonnumeric") firstrow(varlabels) sheetreplace
	restore
}		


** 2: illogical answer **
** correctvalue > survey **

gen value_num = real(value)
order value_num,after(value)

count if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
 
if `r(N)' > 0 {
	preserve
	keep if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("2_illogical") firstrow(varlabels) sheetreplace
	restore
}		


** 3: duplicated answer **
sort partid variable
order partid, before(variable) 

duplicates tag partid variable, gen(dup_ans)
tab dup_ans, m

duplicates tag partid variable comment, gen(dup_ans_all)
tab dup_ans_all, m


count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("3_duplicate") firstrow(varlabels) sheetreplace
	restore
}		

duplicates drop partid variable, force

** Merge with original HFC check outlier output **
** prepare to merge **
drop scto_link // un-necessary var
destring partid enum_id, replace
tostring partid, replace

drop submissiondate


merge 1:1 partid variable using `constmaster'

gen submissiondate2 = dofc(submissiondate)
format submissiondate2 %td


** 4: haven't included yet in report answer **
count if _merge == 2 & submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("4_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 5: data correction **
keep if _merge == 3
drop _merge

drop if mi(correctvalue) & mi(comment)
drop if !mi(correctvalue) & mi(correctvalue_num)
drop if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/02_hfc_constraint_result.xlsx", ///
						sheet("5_datacorrection") firstrow(varlabels) sheetreplace
	restore
}


clear


********************************************************************************
***** HFC: OTHER SPECIFY OUTPUT CHECK *****
********************************************************************************

** Import oroginal outlier file **
import excel using "$BL_HFC/04_checks/02_outputs/output.xlsx", sheet("9. specify") firstrow clear

tempfile othmaster
save `othmaster', replace
clear


** HFC Results Other Specify - Import **
local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/" files "output*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	
	
	import excel using "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/`file'", describe
	return list
	local n_sheets `r(N_worksheet)'
	forvalues j = 1/`n_sheets' {
		local sheet_`j' `r(worksheet_`j')'
		}
		
	forvalues j = 1/`n_sheets' {
		if "`sheet_`j''" == "9. specify" {
			import excel 	using "$BL_HFC/04_checks/03_outputs_check/01_hfc_hh/`file'", ///
							sheet("9. specify") firstrow case(lower) allstring clear
			
			gen source = "`file'"
			append using `bc'
			save `bc', replace
			}
		}
}

** drop missing observation **
drop if mi(partid) & mi(parent) & mi(parent_value) & mi(child) & mi(child_value) & ///
		mi(correctvalue) & mi(comment)
  

* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/03_hfc_otherspecify_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace


** 0: missing answer **
count if mi(correctvalue) & mi(comment)
if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/03_hfc_otherspecify_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: duplicated answer **
sort partid parent parent_value child child_value
order partid, before(parent) 

duplicates tag partid parent parent_value child child_value, gen(dup_ans)
tab dup_ans, m

duplicates tag partid parent parent_value child child_value comment, gen(dup_ans_all)
tab dup_ans_all, m


count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/03_hfc_otherspecify_result.xlsx", ///
						sheet("1_duplicate") firstrow(varlabels) sheetreplace
	restore
}		

duplicates drop partid parent parent_value child child_value, force

** Merge with original HFC check outlier output **
** prepare to merge **
drop scto_link // un-necessary var
destring partid enum_id, replace
tostring partid, replace

drop submissiondate


merge 1:1 partid parent parent_value child child_value using `othmaster'

gen submissiondate2 = dofc(submissiondate)
format submissiondate2 %td

** 2: haven't included yet in report answer **
count if _merge == 2 & submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/03_hfc_otherspecify_result.xlsx", ///
						sheet("2_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 3: data correction **
keep if _merge == 3
drop _merge

drop if mi(correctvalue) & mi(comment)

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/03_hfc_otherspecify_result.xlsx", ///
						sheet("3_datacorrection") firstrow(varlabels) sheetreplace
	restore
}

clear


*******************************************************************************/
********************************************************************************
***************************** VILLAGE ADMIN SURVEY *****************************
********************************************************************************
*******************************************************************************/


********************************************************************************
***** HFC: OUTLIER OUTPUT CHECK *****
********************************************************************************

** Import oroginal outlier file **
import excel using "$BL_HFC/04_checks/02_outputs/output_villadmin.xlsx", sheet("11. outliers") firstrow clear

tempfile outliermaster
save `outliermaster', replace
clear


** HFC Results Outlier - Import **

local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/" files "output_villadmin*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	
	
	import excel using "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/`file'", describe
	return list
	local n_sheets `r(N_worksheet)'
	forvalues j = 1/`n_sheets' {
		local sheet_`j' `r(worksheet_`j')'
		}
		
	forvalues j = 1/`n_sheets' {
		if "`sheet_`j''" == "11. outliers" {
			import excel 	using "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/`file'", ///
							sheet("11. outliers") firstrow case(lower) allstring clear
			
			gen source = "`file'"
			append using `bc'
			save `bc', replace
			}
		}
}


** drop missing observation **
drop if mi(village_id) & mi(vil_id) &  mi(variable) & mi(value) & mi(correctvalue) & mi(comment)

* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace


** 0: missing answer **
replace correctvalue = "" if correctvalue == " "

count if mi(correctvalue) & mi(comment)
if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: nun numeric answer **
gen correctvalue_num = real(correctvalue)
order correctvalue_num,after(correctvalue)

count if !mi(correctvalue) & mi(correctvalue_num)
 
if `r(N)' > 0 {
	preserve 
	keep if !mi(correctvalue) & mi(correctvalue_num)
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
						sheet("1_nonnumeric") firstrow(varlabels) sheetreplace
	restore
}		


** 2: illogical answer **
** correctvalue > survey **

gen value_num = real(value)
order value_num,after(value)

count if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
 
if `r(N)' > 0 {
	preserve
	keep if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
						sheet("2_illogical") firstrow(varlabels) sheetreplace
	restore
}		


** 3: duplicated answer **
sort village_id vil_id variable
order village_id vil_id, before(variable) 

duplicates tag village_id vil_id variable, gen(dup_ans)
tab dup_ans, m

duplicates tag village_id vil_id variable comment, gen(dup_ans_all)
tab dup_ans_all, m


count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
						sheet("3_duplicate") firstrow(varlabels) sheetreplace
	restore
}		

duplicates drop village_id vil_id variable, force

** Merge with original HFC check outlier output **
** prepare to merge **
drop scto_link // un-necessary var
destring vil_id enum_id, replace
drop submissiondate


merge 1:1 village_id vil_id variable using `outliermaster'

gen submissiondate2 = dofc(submissiondate)
format submissiondate2 %td


** 4: haven't included yet in report answer **
count if _merge == 2 & submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
						sheet("4_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 5: data correction **
keep if _merge == 3
drop _merge

drop if mi(correctvalue) & mi(comment)
drop if !mi(correctvalue) & mi(correctvalue_num)
drop if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/04_hfcvill_outlier_result.xlsx", ///
						sheet("5_datacorrection") firstrow(varlabels) sheetreplace
	restore
}
clear


********************************************************************************
***** HFC: CONSTRAINTS OUTPUT CHECK *****
********************************************************************************

** Import oroginal outlier file **
import excel using "$BL_HFC/04_checks/02_outputs/output_villadmin.xlsx", sheet("8. constraints") firstrow clear

tempfile constmaster
save `constmaster', replace
clear


** HFC Results Outlier - Import **

local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/" files "output_villadmin*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	
	
	import excel using "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/`file'", describe
	return list
	local n_sheets `r(N_worksheet)'
	forvalues j = 1/`n_sheets' {
		local sheet_`j' `r(worksheet_`j')'
		}
		
	forvalues j = 1/`n_sheets' {
		if "`sheet_`j''" == "8. constraints" {
			import excel 	using "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/`file'", ///
							sheet("8. constraints") firstrow case(lower) allstring clear
			
			gen source = "`file'"
			append using `bc'
			save `bc', replace
			}
		}
}


** drop missing observation **
drop if mi(village_id) & mi(vil_id) & mi(variable) & mi(value) & mi(correctvalue) & mi(comment)


* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace


** 0: missing answer **
replace correctvalue = "" if correctvalue == " "

count if mi(correctvalue) & mi(comment)
if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: nun numeric answer **
gen correctvalue_num = real(correctvalue)
order correctvalue_num,after(correctvalue)

count if !mi(correctvalue) & mi(correctvalue_num)
 
if `r(N)' > 0 {
	preserve 
	keep if !mi(correctvalue) & mi(correctvalue_num)
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
						sheet("1_nonnumeric") firstrow(varlabels) sheetreplace
	restore
}		


** 2: illogical answer **
** correctvalue > survey **

gen value_num = real(value)
order value_num,after(value)

count if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
 
if `r(N)' > 0 {
	preserve
	keep if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
						sheet("2_illogical") firstrow(varlabels) sheetreplace
	restore
}		


** 3: duplicated answer **
sort village_id vil_id variable
order village_id vil_id, before(variable) 

duplicates tag village_id vil_id variable, gen(dup_ans)
tab dup_ans, m

duplicates tag village_id vil_id variable comment, gen(dup_ans_all)
tab dup_ans_all, m


count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
						sheet("3_duplicate") firstrow(varlabels) sheetreplace
	restore
}		

duplicates drop village_id vil_id variable, force

** Merge with original HFC check outlier output **
** prepare to merge **
drop scto_link // un-necessary var
destring vil_id enum_id, replace
//tostring partid, replace

drop submissiondate


merge 1:1 village_id vil_id variable using `constmaster'

gen submissiondate2 = dofc(submissiondate)
format submissiondate2 %td


** 4: haven't included yet in report answer **
count if _merge == 2 & submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
						sheet("4_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 5: data correction **
keep if _merge == 3
drop _merge

drop if mi(correctvalue) & mi(comment)
drop if !mi(correctvalue) & mi(correctvalue_num)
drop if correctvalue_num > value_num & (!mi(correctvalue_num) & !mi(value_num))

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/05_hfcvill_constraint_result.xlsx", ///
						sheet("5_datacorrection") firstrow(varlabels) sheetreplace
	restore
}
clear


********************************************************************************
***** HFC: OTHER SPECIFY OUTPUT CHECK *****
********************************************************************************

** Import oroginal outlier file **
import excel using "$BL_HFC/04_checks/02_outputs/output_villadmin.xlsx", sheet("9. specify") firstrow clear

tempfile othmaster
save `othmaster', replace
clear


** HFC Results Other Specify - Import **
local xlsx : dir "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/" files "output_villadmin*.xlsx"
di `xlsx'

clear
tempfile bc
save `bc', emptyok

foreach file in `xlsx' {
	di "now improting `file' file"
	
	
	import excel using "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/`file'", describe
	return list
	local n_sheets `r(N_worksheet)'
	forvalues j = 1/`n_sheets' {
		local sheet_`j' `r(worksheet_`j')'
		}
		
	forvalues j = 1/`n_sheets' {
		if "`sheet_`j''" == "9. specify" {
			import excel 	using "$BL_HFC/04_checks/03_outputs_check/01_hfc_vill/`file'", ///
							sheet("9. specify") firstrow case(lower) allstring clear
			
			gen source = "`file'"
			append using `bc'
			save `bc', replace
			}
		}
}

** drop missing observation **
drop if mi(village_id) & mi(vil_id) & mi(parent) & mi(parent_value) & mi(child) & mi(child_value) & ///
		mi(correctvalue) & mi(comment)
  

* saevd as combined bc output answer sheet *
export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/06_otherspecify_result.xlsx", ///
					sheet("all_ans") firstrow(varlabels) sheetreplace


** 0: missing answer **
count if mi(correctvalue) & mi(comment)
if `r(N)' > 0 {
	preserve
	keep if mi(correctvalue) & mi(comment) 
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/06_otherspecify_result.xlsx", ///
						sheet("0_missing") firstrow(varlabels) sheetreplace
	restore
}

** 1: duplicated answer **
sort village_id vil_id parent parent_value child child_value
order village_id vil_id, before(parent) 

duplicates tag village_id vil_id parent parent_value child child_value, gen(dup_ans)
tab dup_ans, m

duplicates tag village_id vil_id parent parent_value child child_value comment, gen(dup_ans_all)
tab dup_ans_all, m


count if dup_ans > 0 & dup_ans_all == 0
 
if `r(N)' > 0 {
	preserve
	keep if dup_ans > 0 & dup_ans_all == 0
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/06_otherspecify_result.xlsx", ///
						sheet("1_duplicate") firstrow(varlabels) sheetreplace
	restore
}		

duplicates drop village_id vil_id parent parent_value child child_value, force

** Merge with original HFC check outlier output **
** prepare to merge **
drop scto_link // un-necessary var
destring vil_id enum_id, replace
//tostring partid, replace

drop submissiondate


merge 1:1 village_id vil_id parent parent_value child child_value using `othmaster'

gen submissiondate2 = dofc(submissiondate)
format submissiondate2 %td

** 2: haven't included yet in report answer **
count if _merge == 2 & submissiondate2 <  td(`c(current_date)')

if `r(N)' > 0 {
	preserve
	keep if _merge == 2 & submissiondate2 <  td(`c(current_date)')
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/06_otherspecify_result.xlsx", ///
						sheet("2_noreportyet") firstrow(varlabels) sheetreplace
	restore
}


** 3: data correction **
keep if _merge == 3
drop _merge

drop if mi(correctvalue) & mi(comment)

if _N > 0 {
	preserve
	export excel using "$BL_HFC/04_checks/03_outputs_check/_checkout/06_otherspecify_result.xlsx", ///
						sheet("3_datacorrection") firstrow(varlabels) sheetreplace
	restore
}
clear

clear




