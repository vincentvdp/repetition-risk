////////////////////////////////
///// SYPA - Data cleaning /////
///// HARVARD/HKS/MPAID'17 /////
///// Vincent Vanderputten /////
///// Ben Brockman		   /////
////////////////////////////////

// Go to Data Folder:
cd ".."
cd ".\Data"
// Load main data
use "eicv_3_4_analysisready_v2.dta", clear
set more off

///////// Clean and Create variable /////////////

// URB/RUR
gen urb=0
replace urb=1 if urban=="Urban"
gen kigali = province=="Kigali City"

//gender
gen female = 0
replace female = gender=="Female"

// PRIMARY
gen prim_grade = 0
replace prim_grade = 1 if grade_y=="Primary 1"
replace prim_grade = 2 if grade_y=="Primary 2"
replace prim_grade = 3 if grade_y=="Primary 3"
replace prim_grade = 4 if grade_y=="Primary 4"
replace prim_grade = 5 if grade_y=="Primary 5"
replace prim_grade = 6 if grade_y=="Primary 6"
drop if prim_grade == 0
// generate dummies
gen p1 = prim_grade == 1
gen p2 = prim_grade == 2
gen p3 = prim_grade == 3
gen p4 = prim_grade == 4
gen p5 = prim_grade == 5
gen p6 = prim_grade == 6

// Alternative "on-track" variable:
gen ontrack2 = (prim_grade + 7) >= age_y

// EICV
gen eicv4 = (eicv==4)
//keep if eicv==4

// RR PR DR
gen any = (promotion + dropout + repeat)>0
keep if any

// hh id:
//destring idhh, gen(hhid)
//summ hhid

// School type
*replace idkey = substr(idkey,2,9)
*merge 1:1 idkey using "C:\data\Laterite_Data\EICV\eicv4_schooltype.dta"
*keep if _merge==2
*drop _merge
replace primarytype="Subsidized" 	if primarytype=="Free susdised" | primarytype=="Free-subsidized" | primarytype=="Subsidised"
gen type_subs = primarytype=="Subsidized"
gen type_priv = primarytype=="Private"

rename district dist_name


// Dropping of observations
gen status = .
replace status = 3 if promotion==1
replace status = 2 if repeat==1
replace status = 1 if dropout==1
drop if status==.
//drop status

// AGE
drop if age_y>22

/*******************************
tab age_y if dropout==1
summ if dropout==1
tab age_y prim_grade if dropout==1
tab status
*******************************/

save "eicv_3_4_edu.dta", replace

//=========== prep merge - POVERTY ===========

// ----------- EICV 4:
use "EICV4_poverty_file.dta", clear
// clean before appending
rename sol sol_jan
rename epov epoverty
rename pov poverty
drop region food foodshare1 qcons rwanda
gen idhh = string(hhid)
//
save "EICV4_pov_v1.dta", replace


// ----------- EICV 3:
use "EICV3_Povertyfile_Jan2014.dta", clear
// clean before appending
drop exp2 exp3 exp13_wh _merge
gen idhh = "C" + string(hhid)
destring district, replace
replace district = round(district/10) + mod(district,100)
//
save "EICV3_pov_v1.dta", replace

// APPEND poverty files (combine EICV 3 and 4)
append using "EICV4_pov_v1.dta"

// cleaning of merged data before saving:
rename member hhsize
rename ae hhsize_ae
gen lncons_ae = ln(sol_jan)
label var lncons_ae "Aggregate consumption/ae Jan14=100"

rename poverty  pov
rename epoverty pov_ext
replace pov =     pov!=0
replace pov_ext = pov_ext!=0

gen ln_exp_edu_ae = ln(exp1/hhsize_ae)
label var ln_exp_edu "log of per adult equiv. education expenses"

*save "EICV3-4_pov_both_v1.dta", replace


//============ merge EDU and POV data ================

*use "eicv_3_4_edu.dta", clear
merge 1:m idhh using "eicv_3_4_edu.dta"
keep if _merge==3
drop _merge
save "eicv_3_4_edu.dta", replace

// =================== Merge and clean further ================ (Dec 15, 2016)
//!!!! *** CHANGE IF EICV 3 IS ALSO NEEDED *** !!!!
drop if eicv==3 

//drop missing data variables:
global p=1
foreach varname of varlist * {
	qui count if missing(`varname')
	if (r(N)/_N) >= $p {
		drop `varname'
		disp "dropped `varname' for too much missing data"
	}
}

// drop duplicate variables or variables with implicit repetition or dropout info:
drop	eicv age year idp gender age2012 age2013 everattended schoollast12 enrol enrol_y enrol_yplus1 grade_yplus1 ///
		age_yplus1 grade2009 enrol2009 grade2010 enrol2010 dropout2010 repeat2010 grade_var_JC enrol2012 grade2013 ///
		enrol2013 dropout2013 repeat2013 grade2013_id promotion2010 entry2010 promotion2013 entry grade_yplus1_id eicv4 ///
		dist_name urban grade_y grade2012 grade2012_id grade_y_id ontrack_y ontrack_yplus1 any clust
drop promotion // keep repetition and dropout!!

// gen personal ID:
replace idkey = substr(idkey,2,9)
destring idkey, gen(pid)



// What's happaning with: type_subs type_priv ?? (all 0)
// ADD:
* cleaned cost stuff! if added ==> drop s4aq11a s4aq11b s4aq11c s4aq11d s4aq11e s4aq11f s4aq11g s4aq11h
* school type: later!

save "eicv_4.dta", replace

// =======================prep other data to be merged with the above:
use "cs_s1_s2_s3_s4_s6a_s6e_s6f_person.dta", clear
drop	hhid province district ur2012 ur2_2012 region weight hhtype s0q19m s0q19y clust rwanda surveyh s1q1 s1q3y s1q3m ///
		s2q1 s3q1 s4aq1 s4aq1 s4aq2 s4aq3 s4aq4a s4aq4b s4aq5 s4aq6a s4aq6b s4aq7 s4aq16 s4aq17 s4bq1 s4bq2 s6eq0a
drop s4aq11a s4aq11b s4aq11c s4aq11d s4aq11e s4aq11f s4aq11g s4aq11h // add cleaned cost variables later!

// more merging...
merge 1:1 pid using "eicv_4.dta"
keep if _merge==3
drop _merge
save "eicv_4.dta", replace

// =======================prep other data to be merged with the above:
use "eicv_cost_own_v3_sypa.dta", clear /********************** ISSUE HERE? **************************/
keep if year>=2013 // only keep EICV4
keep	idkey schooltype freeschooling paidtuition costsboardtransp costsnontuition totalcosts ///
		paid_nontuition paid_contrib paid_uniform paid_material paid_trnsbrd

destring idkey, gen(pid)
drop idkey

// more merging...
merge 1:1 pid using "eicv_4.dta"
keep if _merge==3
drop _merge
save "eicv_4.dta", replace

// =========================== Merge with HH and HH-Head data ==================================
merge m:1 hhid using "eicv4_hh_data_D.dta"
keep if _merge==3
drop _merge

//====================================
//drop missing data variables:
global p=1
foreach varname of varlist * {
	qui count if missing(`varname')
	if (r(N)/_N) >= $p {
		drop `varname'
		disp "dropped `varname' for too much missing data"
	}
}

// Finally: drop id and other non-prediction variables
drop idkey hhid idhh pid
// also, drop weights for now!
drop HH_WT hh_wt pop_wt
// drop variables with all same value:
drop s1q15 //type_priv type_subs

//========================== CLEAN DATA ==========================
// COST cleaning
gen reasonablecost = .
foreach varname of varlist cost*{
	replace reasonablecost = (`varname'<800000) | (`varname'==.)
	replace `varname'=800000 if !reasonablecost
}
drop reasonablecost

// for now, just get something compilable!
// for now: drop string variables!
drop province missedclasslastweek missedreason schoolproblems toilets whopays

// correct tpe of school dummies
replace type_priv = schooltype==2
replace type_subs = schooltype==3

order repeat dropout

save "eicv_4", replace

// preserve
// keep if dropout==1
// set more off
// global p=0.5
// foreach varname of varlist * {
// 	qui count if missing(`varname')
// 	//display (r(N)/_N)
// 	if (r(N)/_N) >= $p {
// 		display "`varname'"
// 		display (r(N)/_N)
// 	}
// }
// restore

// bad dummies: replace 2 (no) by 0 (new no) and replace empties by 9 (missing):
foreach varname of varlist s1q7 s2q2 s3q4 s3q6 s4aq10 s4aq13 s4bq3 s4bq4 s4bq5 s4bq7 s4bq8 s6aq2 s6aq3 s6aq4 s6aq5 s6aq6 s6eq1 s6eq2 s6eq7 s6eq8 s6eq10 s6eq13 s6eq17 s6fq1 s6fq3 s6fq5 s6fq7 s6fq9 s6fq11{
	replace `varname'=0 if `varname'==2
	replace `varname'=9 if `varname'==.
}

/* TEST STUFF:
set more off
foreach varname of varlist s1q7 s2q2 s3q4 s3q6 s4aq10 s4aq13 s4bq3 s4bq4 s4bq5 s4bq7 s4bq8 s6aq2 s6aq3 s6aq4 s6aq5 s6aq6 s6eq1 s6eq2 s6eq7 s6eq8 s6eq10 s6eq13 s6eq17 s6fq1 s6fq3 s6fq5 s6fq7 s6fq9 s6fq11{
	//tab `varname', missing
	codebook `varname'
}*/

// Categorical integer vars that need encoding, i.e. dummy creation:
foreach varname of varlist  schooltype quintile s1q2 s1q4 s1q5 s1q6 s1q8 s1q9 s1q10 s1q12 s1q13 s1q14 s2q4 s2q5 s2q7 s2q8 s3q2 s3q3 s3q5 s3q7 s4aq9 s4aq12 s4aq15 s4bq6 s6aq8 s6eq3 s6eq4 s6eq5 s6eq6 id1 district{
	// create dummies for each category:
	//... // ==> see PYTHON
	// replace missing categories with 999 code
	replace `varname'=999 if `varname'==.
}

// drop these:
drop s1q11 s4aq8 s6eq9 s6eq11 s6eq12a s6eq12b s6eq14 s6eq15 s6eq16 s6eq18 s6eq19 s6eq20 s6eq21 ur

// for now: replace any remaining missing values (should be non-dummies and non-catgorical variables) with 0!
foreach varname of varlist * {
	replace `varname'=0 if `varname'==.
	// more advanced data cleaning needed?
}

*******************************
tab age_y if dropout==1
summ if dropout==1
tab age_y prim_grade if dropout==1
tab status
*******************************

// check what changed: (mostly repeaters' status changed!) ==> ontrack2 should be the more accurate estimate!
tab ontrack ontrack2 if dropout
tab ontrack ontrack2 if repeat
tab ontrack ontrack2 if (!repeat & !dropout)
// set more off
// foreach varname of varlist * {
// 	qui ttest `varname', by(ontrackchanged)
// 	if r(p)<0.10{
// 		display "`varname'"
// 		display r(p)
// 		display "------------"
// 	}
// }

// replace old "ontrack" by new "ontrack2":
replace ontrack = ontrack2
drop ontrack2

// change costs and expenses to their log version!
foreach varname of varlist exp* cost* cons* sol_jan {
	replace `varname' = 1 if `varname' < 1
	replace `varname' = ln(`varname')
	rename `varname' ln_`varname'
}

// DROP:
drop status // important to drop! Contains info on repetition and dropout...

// SAVE:
*save "eicv_4_v6_categories.dta", replace
export delimited using "eicv_4_v6_categories.csv", nolabel replace


////===================
// keep only baseline model variables and save, then restore:
preserve
keep repeat dropout female age_y p2 p3 p4 p5 p6 ontrack type_subs type_priv urb kigali ln_coststotal ln_exp_edu_ae hhsize_ae lncons_ae pov_ext
save "eicv_4_v6_basevars.dta", replace
restore
