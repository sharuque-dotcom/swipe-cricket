class_name IplData
extends RefCounted
## IPL 2026: the ten franchises, their squads after the December 2025 auction, a first-choice
## XI in batting order, the five who bowl, and the league fixtures.
##
## Squads and fixtures: Wisden, The Federal, Outlook India and Khel Now (Dec 2025 - Mar 2026).
## Batting orders, ratings [power, timing] and bowling styles are this game's own judgement.
## For personal use only: real names, no logos.
##
## Bowling styles map onto the game's actions (BowlerProfile):
##   rf fast (express), rft tall fast, sling slinger, rm medium/cutters, rms swing medium,
##   lf left-arm fast, lfm left-arm medium swing, ob off spin, lb leg spin (wrist),
##   sla left-arm orthodox, lws left-arm wrist spin.

const TITLE := "IPL 2026"
const LEAGUE_NAME := "Indian Premier League"
const PICK_TEXT := "Play the 2026 season with a real squad: all 70 league fixtures in order, the points table, and the play-offs. You bat; every other match is played out for you."
const SQUAD_NOTE := "Squads as of March 2026. Batting orders and ratings are the game's own."
const STAGES := ["Qualifier 1", "Eliminator", "Qualifier 2", "Final"]
## Modern IPL scoring: first innings around 185-190.
const PAR := 1.24

const TEAMS := {
	"CSK": {"name": "Chennai Super Kings", "kit": Color(0.98, 0.80, 0.08), "trim": Color(0.10, 0.22, 0.60),
		"home": "Chennai", "captain": "Ruturaj Gaikwad",
		"xi": [["Sanju Samson", "Wicketkeeper", 0.82, 0.86], ["Ruturaj Gaikwad", "Opener", 0.72, 0.92], ["Ayush Mhatre", "Top order", 0.78, 0.78],
			["Dewald Brevis", "Middle order", 0.92, 0.72], ["Shivam Dube", "Power hitter", 0.95, 0.70], ["MS Dhoni", "Finisher", 0.82, 0.70],
			["Jamie Overton", "All-rounder", 0.80, 0.55], ["Noor Ahmad", "Bowler", 0.30, 0.30], ["Rahul Chahar", "Bowler", 0.35, 0.35],
			["Khaleel Ahmed", "Bowler", 0.25, 0.20], ["Matt Henry", "Bowler", 0.40, 0.30]],
		"attack": [["Khaleel Ahmed", "lf", 0.82], ["Matt Henry", "rft", 0.86], ["Jamie Overton", "rf", 0.80],
			["Noor Ahmad", "lws", 0.88], ["Rahul Chahar", "lb", 0.78]],
		"squad": ["Ruturaj Gaikwad", "MS Dhoni", "Sanju Samson", "Ayush Mhatre", "Shivam Dube", "Urvil Patel", "Kartik Sharma",
			"Sarfaraz Khan", "Aman Khan", "Prashant Veer", "Matthew Short*", "Rahul Chahar", "Akeal Hosein*", "Matt Henry*",
			"Zak Foulkes*", "Dewald Brevis*", "Ramakrishna Ghosh", "Jamie Overton*", "Shreyas Gopal", "Noor Ahmad*",
			"Khaleel Ahmed", "Mukesh Choudhary", "Anshul Kamboj", "Gurjapneet Singh", "Spencer Johnson*"]},
	"MI": {"name": "Mumbai Indians", "kit": Color(0.02, 0.30, 0.65), "trim": Color(0.86, 0.70, 0.22),
		"home": "Mumbai", "captain": "Hardik Pandya",
		"xi": [["Rohit Sharma", "Opener", 0.92, 0.82], ["Ryan Rickelton", "Wicketkeeper", 0.84, 0.80], ["Suryakumar Yadav", "Top order", 0.92, 0.88],
			["Tilak Varma", "Middle order", 0.80, 0.86], ["Hardik Pandya", "Finisher", 0.92, 0.75], ["Will Jacks", "All-rounder", 0.85, 0.75],
			["Naman Dhir", "Finisher", 0.80, 0.66], ["Mitchell Santner", "All-rounder", 0.62, 0.62], ["Deepak Chahar", "Bowler", 0.45, 0.40],
			["Trent Boult", "Bowler", 0.30, 0.25], ["Jasprit Bumrah", "Bowler", 0.20, 0.20]],
		"attack": [["Trent Boult", "lfm", 0.90], ["Jasprit Bumrah", "sling", 1.0], ["Hardik Pandya", "rf", 0.78],
			["Mitchell Santner", "sla", 0.84], ["Will Jacks", "ob", 0.70]],
		"squad": ["Rohit Sharma", "Suryakumar Yadav", "Tilak Varma", "Hardik Pandya", "Naman Dhir", "Raj Angad Bawa", "Raghu Sharma",
			"Ashwani Kumar", "Deepak Chahar", "Jasprit Bumrah", "Trent Boult*", "Mayank Markande", "Shardul Thakur", "Robin Minz",
			"Ryan Rickelton*", "Quinton de Kock*", "Allah Ghazanfar*", "Corbin Bosch*", "Mitchell Santner*", "Sherfane Rutherford*",
			"Will Jacks*", "Atharva Ankolekar", "Danish Malewar", "Mayank Rawat", "Mohammad Izhar"]},
	"RCB": {"name": "Royal Challengers Bengaluru", "kit": Color(0.82, 0.08, 0.12), "trim": Color(0.88, 0.72, 0.25),
		"home": "Bengaluru", "captain": "Rajat Patidar",
		"xi": [["Phil Salt", "Wicketkeeper", 0.92, 0.78], ["Virat Kohli", "Opener", 0.84, 0.98], ["Devdutt Padikkal", "Top order", 0.74, 0.80],
			["Rajat Patidar", "Middle order", 0.86, 0.80], ["Jitesh Sharma", "Wicketkeeper", 0.84, 0.66], ["Tim David", "Power hitter", 0.98, 0.66],
			["Krunal Pandya", "All-rounder", 0.68, 0.66], ["Romario Shepherd", "All-rounder", 0.90, 0.50], ["Bhuvneshwar Kumar", "Bowler", 0.35, 0.40],
			["Josh Hazlewood", "Bowler", 0.20, 0.25], ["Suyash Sharma", "Bowler", 0.15, 0.15]],
		"attack": [["Bhuvneshwar Kumar", "rms", 0.86], ["Josh Hazlewood", "rft", 0.94], ["Romario Shepherd", "rm", 0.72],
			["Krunal Pandya", "sla", 0.80], ["Suyash Sharma", "lb", 0.80]],
		"squad": ["Virat Kohli", "Devdutt Padikkal", "Rajat Patidar", "Venkatesh Iyer", "Krunal Pandya", "Bhuvneshwar Kumar", "Yash Dayal",
			"Suyash Sharma", "Abhinandan Singh", "Swapnil Singh", "Rasikh Dar", "Satvik Deswal", "Vihaan Malhotra", "Kanishk Chouhan",
			"Vicky Ostwal", "Mangesh Yadav", "Jitesh Sharma", "Phil Salt*", "Jacob Bethell*", "Josh Hazlewood*", "Romario Shepherd*",
			"Nuwan Thushara*", "Tim David*", "Jordan Cox*", "Jacob Duffy*"]},
	"KKR": {"name": "Kolkata Knight Riders", "kit": Color(0.24, 0.10, 0.46), "trim": Color(0.88, 0.72, 0.25),
		"home": "Kolkata", "captain": "Ajinkya Rahane",
		"xi": [["Finn Allen", "Opener", 0.94, 0.70], ["Sunil Narine", "Opener", 0.88, 0.60], ["Ajinkya Rahane", "Top order", 0.68, 0.86],
			["Cameron Green", "All-rounder", 0.90, 0.80], ["Angkrish Raghuvanshi", "Middle order", 0.74, 0.76], ["Rinku Singh", "Finisher", 0.88, 0.82],
			["Rovman Powell", "Power hitter", 0.95, 0.60], ["Ramandeep Singh", "All-rounder", 0.82, 0.55], ["Vaibhav Arora", "Bowler", 0.30, 0.25],
			["Umran Malik", "Bowler", 0.25, 0.20], ["Varun Chakravarthy", "Bowler", 0.15, 0.15]],
		"attack": [["Vaibhav Arora", "rm", 0.76], ["Umran Malik", "rf", 0.74], ["Cameron Green", "rft", 0.78],
			["Sunil Narine", "ob", 0.92], ["Varun Chakravarthy", "lb", 0.92]],
		"squad": ["Ajinkya Rahane", "Angkrish Raghuvanshi", "Manish Pandey", "Rinku Singh", "Rahul Tripathi", "Ramandeep Singh", "Anukul Roy",
			"Harshit Rana", "Umran Malik", "Vaibhav Arora", "Varun Chakravarthy", "Sarthak Ranjan", "Kartik Tyagi", "Daksh Kamra",
			"Tejasvi Singh", "Prashant Solanki", "Akash Deep", "Sunil Narine*", "Rovman Powell*", "Cameron Green*",
			"Matheesha Pathirana*", "Finn Allen*", "Rachin Ravindra*", "Mustafizur Rahman*", "Tim Seifert*"]},
	"SRH": {"name": "Sunrisers Hyderabad", "kit": Color(0.97, 0.45, 0.08), "trim": Color(0.08, 0.08, 0.10),
		"home": "Hyderabad", "captain": "Ishan Kishan",
		"xi": [["Travis Head", "Opener", 0.96, 0.80], ["Abhishek Sharma", "Opener", 0.96, 0.76], ["Ishan Kishan", "Wicketkeeper", 0.86, 0.76],
			["Heinrich Klaasen", "Middle order", 0.97, 0.84], ["Nitish Kumar Reddy", "All-rounder", 0.80, 0.70], ["Liam Livingstone", "Power hitter", 0.94, 0.66],
			["Aniket Verma", "Finisher", 0.86, 0.60], ["Harshal Patel", "Bowler", 0.50, 0.40], ["Pat Cummins", "Bowler", 0.66, 0.50],
			["Jaydev Unadkat", "Bowler", 0.25, 0.25], ["Zeeshan Ansari", "Bowler", 0.15, 0.15]],
		"attack": [["Pat Cummins", "rf", 0.90], ["Jaydev Unadkat", "lfm", 0.76], ["Harshal Patel", "rm", 0.82],
			["Zeeshan Ansari", "lb", 0.72], ["Abhishek Sharma", "sla", 0.66]],
		"squad": ["Abhishek Sharma", "Aniket Verma", "Harsh Dubey", "Harshal Patel", "Nitish Kumar Reddy", "Jaydev Unadkat", "Zeeshan Ansari",
			"Shivang Kumar", "Krains Fuletra", "Onkar Tarmale", "Shivam Mavi", "Amit Kumar", "Praful Hinge", "Sakib Hussain",
			"Smaran Ravichandran", "Ishan Kishan", "Salil Arora", "Heinrich Klaasen*", "Travis Head*", "Pat Cummins*", "Kamindu Mendis*",
			"Brydon Carse*", "Eshan Malinga*", "Liam Livingstone*", "David Payne*"]},
	"DC": {"name": "Delhi Capitals", "kit": Color(0.06, 0.20, 0.56), "trim": Color(0.88, 0.16, 0.20),
		"home": "Delhi", "captain": "Axar Patel",
		"xi": [["KL Rahul", "Wicketkeeper", 0.78, 0.94], ["Pathum Nissanka", "Opener", 0.78, 0.84], ["Tristan Stubbs", "Middle order", 0.90, 0.76],
			["Axar Patel", "All-rounder", 0.80, 0.72], ["David Miller", "Finisher", 0.92, 0.80], ["Ashutosh Sharma", "Finisher", 0.90, 0.62],
			["Sameer Rizvi", "Middle order", 0.80, 0.62], ["Vipraj Nigam", "All-rounder", 0.62, 0.45], ["Mitchell Starc", "Bowler", 0.50, 0.35],
			["Kuldeep Yadav", "Bowler", 0.20, 0.30], ["T Natarajan", "Bowler", 0.10, 0.10]],
		"attack": [["Mitchell Starc", "lf", 0.92], ["T Natarajan", "lf", 0.80], ["Vipraj Nigam", "lb", 0.70],
			["Kuldeep Yadav", "lws", 0.92], ["Axar Patel", "sla", 0.88]],
		"squad": ["Abishek Porel", "Ajay Mandal", "Ashutosh Sharma", "Axar Patel", "Karun Nair", "KL Rahul", "Kuldeep Yadav", "Madhav Tiwari",
			"Mukesh Kumar", "Nitish Rana", "Sameer Rizvi", "T Natarajan", "Tripurana Vijay", "Vipraj Nigam", "Auqib Nabi Dar",
			"Sahil Parikh", "Prithvi Shaw", "Dushmantha Chameera*", "Mitchell Starc*", "Tristan Stubbs*", "David Miller*",
			"Kyle Jamieson*", "Ben Duckett*", "Pathum Nissanka*", "Lungi Ngidi*"]},
	"PBKS": {"name": "Punjab Kings", "kit": Color(0.86, 0.12, 0.16), "trim": Color(0.85, 0.86, 0.90),
		"home": "New Chandigarh", "captain": "Shreyas Iyer",
		"xi": [["Priyansh Arya", "Opener", 0.92, 0.72], ["Prabhsimran Singh", "Wicketkeeper", 0.88, 0.74], ["Shreyas Iyer", "Top order", 0.86, 0.90],
			["Nehal Wadhera", "Middle order", 0.80, 0.74], ["Shashank Singh", "Finisher", 0.86, 0.72], ["Marcus Stoinis", "All-rounder", 0.90, 0.70],
			["Azmatullah Omarzai", "All-rounder", 0.80, 0.62], ["Marco Jansen", "All-rounder", 0.80, 0.55], ["Harpreet Brar", "Bowler", 0.45, 0.40],
			["Arshdeep Singh", "Bowler", 0.20, 0.20], ["Yuzvendra Chahal", "Bowler", 0.10, 0.10]],
		"attack": [["Arshdeep Singh", "lf", 0.92], ["Marco Jansen", "lf", 0.84], ["Azmatullah Omarzai", "rft", 0.76],
			["Harpreet Brar", "sla", 0.76], ["Yuzvendra Chahal", "lb", 0.88]],
		"squad": ["Harnoor Singh Pannu", "Arshdeep Singh", "Azmatullah Omarzai*", "Nehal Wadhera", "Lockie Ferguson*", "Harpreet Brar",
			"Prabhsimran Singh", "Vyshak Vijaykumar", "Marco Jansen*", "Priyansh Arya", "Xavier Bartlett*", "Marcus Stoinis*",
			"Pyla Avinash", "Yash Thakur", "Mitchell Owen*", "Shashank Singh", "Yuzvendra Chahal", "Musheer Khan", "Shreyas Iyer",
			"Ben Dwarshuis*", "Suryansh Shedge", "Vishnu Vinod", "Cooper Connolly*", "Pravin Dubey", "Vishal Nishad"]},
	"RR": {"name": "Rajasthan Royals", "kit": Color(0.92, 0.18, 0.55), "trim": Color(0.08, 0.20, 0.55),
		"home": "Jaipur", "captain": "Riyan Parag",
		"xi": [["Yashasvi Jaiswal", "Opener", 0.92, 0.86], ["Vaibhav Suryavanshi", "Opener", 0.96, 0.70], ["Riyan Parag", "Top order", 0.86, 0.78],
			["Dhruv Jurel", "Wicketkeeper", 0.80, 0.76], ["Shimron Hetmyer", "Finisher", 0.94, 0.68], ["Ravindra Jadeja", "All-rounder", 0.78, 0.74],
			["Donovan Ferreira", "Power hitter", 0.90, 0.60], ["Jofra Archer", "Bowler", 0.55, 0.40], ["Ravi Bishnoi", "Bowler", 0.20, 0.20],
			["Sandeep Sharma", "Bowler", 0.15, 0.20], ["Nandre Burger", "Bowler", 0.25, 0.20]],
		"attack": [["Jofra Archer", "rf", 0.94], ["Nandre Burger", "lf", 0.78], ["Sandeep Sharma", "rms", 0.80],
			["Ravindra Jadeja", "sla", 0.88], ["Ravi Bishnoi", "lb", 0.84]],
		"squad": ["Dhruv Jurel", "Jofra Archer*", "Donovan Ferreira*", "Lhuan-dre Pretorius*", "Kwena Maphaka*", "Ravindra Jadeja",
			"Shimron Hetmyer*", "Nandre Burger*", "Riyan Parag", "Shubham Dubey", "Sandeep Sharma", "Dasun Shanaka*",
			"Vaibhav Suryavanshi", "Tushar Deshpande", "Yashasvi Jaiswal", "Yudhvir Singh Charak", "Ravi Singh", "Ravi Bishnoi",
			"Aman Rao", "Sushant Mishra", "Yash Raj Punja", "Vignesh Puthur", "Brijesh Sharma", "Adam Milne*", "Kuldeep Sen"]},
	"LSG": {"name": "Lucknow Super Giants", "kit": Color(0.05, 0.25, 0.56), "trim": Color(0.95, 0.46, 0.10),
		"home": "Lucknow", "captain": "Rishabh Pant",
		"xi": [["Mitchell Marsh", "Opener", 0.94, 0.76], ["Aiden Markram", "Opener", 0.84, 0.84], ["Nicholas Pooran", "Middle order", 0.98, 0.78],
			["Rishabh Pant", "Wicketkeeper", 0.90, 0.72], ["Ayush Badoni", "Middle order", 0.78, 0.74], ["Abdul Samad", "Finisher", 0.88, 0.60],
			["Shahbaz Ahmed", "All-rounder", 0.62, 0.55], ["Digvesh Rathi", "Bowler", 0.20, 0.20], ["Mohammed Shami", "Bowler", 0.30, 0.25],
			["Avesh Khan", "Bowler", 0.25, 0.20], ["Mayank Yadav", "Bowler", 0.15, 0.15]],
		"attack": [["Mohammed Shami", "rft", 0.88], ["Mayank Yadav", "rf", 0.82], ["Avesh Khan", "rm", 0.76],
			["Digvesh Rathi", "lb", 0.80], ["Shahbaz Ahmed", "sla", 0.66]],
		"squad": ["Rishabh Pant", "Nicholas Pooran*", "Josh Inglis*", "Mukul Choudhary", "Abdul Samad", "Aiden Markram*", "Matthew Breetzke*",
			"Mitchell Marsh*", "Ayush Badoni", "Himmat Singh", "Arshin Kulkarni", "Akshat Raghuwanshi", "Wanindu Hasaranga*",
			"Akash Singh", "Avesh Khan", "Digvesh Rathi", "Manimaran Siddharth", "Shahbaz Ahmed", "Mayank Yadav", "Mohammed Shami",
			"Mohsin Khan", "Prince Yadav", "Anrich Nortje*", "Arjun Tendulkar", "Naman Tiwari"]},
	"GT": {"name": "Gujarat Titans", "kit": Color(0.07, 0.14, 0.30), "trim": Color(0.86, 0.70, 0.30),
		"home": "Ahmedabad", "captain": "Shubman Gill",
		"xi": [["Shubman Gill", "Opener", 0.82, 0.94], ["B Sai Sudharsan", "Opener", 0.80, 0.92], ["Jos Buttler", "Wicketkeeper", 0.94, 0.86],
			["Glenn Phillips", "Middle order", 0.90, 0.72], ["M Shahrukh Khan", "Finisher", 0.88, 0.60], ["Rahul Tewatia", "Finisher", 0.82, 0.66],
			["Washington Sundar", "All-rounder", 0.66, 0.70], ["Rashid Khan", "All-rounder", 0.82, 0.55], ["Kagiso Rabada", "Bowler", 0.40, 0.30],
			["Mohammed Siraj", "Bowler", 0.20, 0.15], ["Prasidh Krishna", "Bowler", 0.15, 0.15]],
		"attack": [["Mohammed Siraj", "rf", 0.86], ["Kagiso Rabada", "rf", 0.92], ["Prasidh Krishna", "rft", 0.86],
			["Rashid Khan", "lb", 0.94], ["Washington Sundar", "ob", 0.78]],
		"squad": ["Shubman Gill", "Anuj Rawat", "Kumar Kushagra", "Jos Buttler*", "B Sai Sudharsan", "M Shahrukh Khan", "Rahul Tewatia",
			"Washington Sundar", "Gurnoor Brar", "Ishant Sharma", "Jayant Yadav", "Manav Suthar", "Mohammed Siraj", "Nishant Sindhu",
			"Arshad Khan", "Prasidh Krishna", "R Sai Kishore", "Ashok Sharma", "Prithvi Raj", "Glenn Phillips*", "Kagiso Rabada*",
			"Rashid Khan*", "Jason Holder*", "Tom Banton*", "Luke Wood*"]},
}
const ORDER := ["CSK", "MI", "RCB", "KKR", "SRH", "DC", "PBKS", "RR", "LSG", "GT"]

## How each ground plays.
const GROUNDS := {"Chennai": "dusty", "Mumbai": "flat", "Bengaluru": "flat", "Kolkata": "good", "Hyderabad": "flat",
	"Delhi": "good", "New Chandigarh": "green", "Jaipur": "good", "Lucknow": "dusty", "Ahmedabad": "good",
	"Guwahati": "good", "Dharamshala": "green", "Raipur": "good"}

## League stage: [match, date, home, away, ground].
const FIXTURES := [
	[1, "2026-03-28", "RCB", "SRH", "Bengaluru"],
	[2, "2026-03-29", "MI", "KKR", "Mumbai"],
	[3, "2026-03-30", "RR", "CSK", "Guwahati"],
	[4, "2026-03-31", "PBKS", "GT", "New Chandigarh"],
	[5, "2026-04-01", "LSG", "DC", "Lucknow"],
	[6, "2026-04-02", "KKR", "SRH", "Kolkata"],
	[7, "2026-04-03", "CSK", "PBKS", "Chennai"],
	[8, "2026-04-04", "DC", "MI", "Delhi"],
	[9, "2026-04-04", "GT", "RR", "Ahmedabad"],
	[10, "2026-04-05", "SRH", "LSG", "Hyderabad"],
	[11, "2026-04-05", "RCB", "CSK", "Bengaluru"],
	[12, "2026-04-06", "KKR", "PBKS", "Kolkata"],
	[13, "2026-04-07", "RR", "MI", "Guwahati"],
	[14, "2026-04-08", "DC", "GT", "Delhi"],
	[15, "2026-04-09", "KKR", "LSG", "Kolkata"],
	[16, "2026-04-10", "RR", "RCB", "Guwahati"],
	[17, "2026-04-11", "PBKS", "SRH", "New Chandigarh"],
	[18, "2026-04-11", "CSK", "DC", "Chennai"],
	[19, "2026-04-12", "LSG", "GT", "Lucknow"],
	[20, "2026-04-12", "MI", "RCB", "Mumbai"],
	[21, "2026-04-13", "SRH", "RR", "Hyderabad"],
	[22, "2026-04-14", "CSK", "KKR", "Chennai"],
	[23, "2026-04-15", "RCB", "LSG", "Bengaluru"],
	[24, "2026-04-16", "MI", "PBKS", "Mumbai"],
	[25, "2026-04-17", "GT", "KKR", "Ahmedabad"],
	[26, "2026-04-18", "RCB", "DC", "Bengaluru"],
	[27, "2026-04-18", "SRH", "CSK", "Hyderabad"],
	[28, "2026-04-19", "KKR", "RR", "Kolkata"],
	[29, "2026-04-19", "PBKS", "LSG", "New Chandigarh"],
	[30, "2026-04-20", "GT", "MI", "Ahmedabad"],
	[31, "2026-04-21", "SRH", "DC", "Hyderabad"],
	[32, "2026-04-22", "LSG", "RR", "Lucknow"],
	[33, "2026-04-23", "MI", "CSK", "Mumbai"],
	[34, "2026-04-24", "RCB", "GT", "Bengaluru"],
	[35, "2026-04-25", "DC", "PBKS", "Delhi"],
	[36, "2026-04-25", "RR", "SRH", "Jaipur"],
	[37, "2026-04-26", "GT", "CSK", "Ahmedabad"],
	[38, "2026-04-26", "LSG", "KKR", "Lucknow"],
	[39, "2026-04-27", "DC", "RCB", "Delhi"],
	[40, "2026-04-28", "PBKS", "RR", "New Chandigarh"],
	[41, "2026-04-29", "MI", "SRH", "Mumbai"],
	[42, "2026-04-30", "GT", "RCB", "Ahmedabad"],
	[43, "2026-05-01", "RR", "DC", "Jaipur"],
	[44, "2026-05-02", "CSK", "MI", "Chennai"],
	[45, "2026-05-03", "SRH", "KKR", "Hyderabad"],
	[46, "2026-05-03", "GT", "PBKS", "Ahmedabad"],
	[47, "2026-05-04", "MI", "LSG", "Mumbai"],
	[48, "2026-05-05", "DC", "CSK", "Delhi"],
	[49, "2026-05-06", "SRH", "PBKS", "Hyderabad"],
	[50, "2026-05-07", "LSG", "RCB", "Lucknow"],
	[51, "2026-05-08", "DC", "KKR", "Delhi"],
	[52, "2026-05-09", "RR", "GT", "Jaipur"],
	[53, "2026-05-10", "CSK", "LSG", "Chennai"],
	[54, "2026-05-10", "RCB", "MI", "Raipur"],
	[55, "2026-05-11", "PBKS", "DC", "Dharamshala"],
	[56, "2026-05-12", "GT", "SRH", "Ahmedabad"],
	[57, "2026-05-13", "RCB", "KKR", "Raipur"],
	[58, "2026-05-14", "PBKS", "MI", "Dharamshala"],
	[59, "2026-05-15", "LSG", "CSK", "Lucknow"],
	[60, "2026-05-16", "KKR", "GT", "Kolkata"],
	[61, "2026-05-17", "PBKS", "RCB", "Dharamshala"],
	[62, "2026-05-17", "DC", "RR", "Delhi"],
	[63, "2026-05-18", "CSK", "SRH", "Chennai"],
	[64, "2026-05-19", "RR", "LSG", "Jaipur"],
	[65, "2026-05-20", "KKR", "MI", "Kolkata"],
	[66, "2026-05-21", "CSK", "GT", "Chennai"],
	[67, "2026-05-22", "SRH", "RCB", "Hyderabad"],
	[68, "2026-05-23", "LSG", "PBKS", "Lucknow"],
	[69, "2026-05-24", "MI", "RR", "Mumbai"],
	[70, "2026-05-24", "KKR", "DC", "Kolkata"],
]
## Play-offs: dates and grounds as played in 2026; the teams come from this season's table.
const PLAYOFFS := [["Qualifier 1", "2026-05-26", "Dharamshala"], ["Eliminator", "2026-05-27", "New Chandigarh"],
	["Qualifier 2", "2026-05-29", "New Chandigarh"], ["Final", "2026-05-31", "Ahmedabad"]]

## The bowling styles as the game's bowler profiles.
const STYLES := {
	"rf": {"action": "express", "arm": "R", "style": "pace", "label": "RIGHT-ARM FAST", "pace": [36.0, 40.0], "release": Vector3(0.44, 2.18, 0.0),
		"swing": 0.8, "swing_chance": 0.4, "inswing": 0.5, "seam": 1.0, "yorker": 0.06, "trait": "Pace and bounce"},
	"rft": {"action": "tall", "arm": "R", "style": "pace", "label": "RIGHT-ARM FAST-MEDIUM", "pace": [34.0, 38.0], "release": Vector3(0.40, 2.36, 0.0),
		"swing": 0.7, "swing_chance": 0.4, "inswing": 0.5, "seam": 1.3, "short": 0.12, "trait": "Hits the deck, hard lengths, seam"},
	"sling": {"action": "sling", "arm": "R", "style": "pace", "label": "RIGHT-ARM FAST  ·  UNIQUE ACTION", "pace": [36.0, 40.0], "release": Vector3(0.66, 1.98, 0.35),
		"swing": 1.0, "swing_chance": 0.5, "inswing": 0.55, "seam": 1.1, "yorker": 0.16, "trait": "Short run, late release; yorkers and slower balls at will"},
	"rm": {"action": "skiddy", "arm": "R", "style": "pace", "label": "RIGHT-ARM MEDIUM", "pace": [31.0, 35.0], "release": Vector3(0.55, 2.0, 0.0),
		"swing": 0.5, "swing_chance": 0.3, "inswing": 0.5, "seam": 1.2, "cutters": 0.3, "trait": "Cutters and slower balls"},
	"rms": {"action": "express", "arm": "R", "style": "swing", "label": "RIGHT-ARM SWING", "pace": [33.0, 37.0], "release": Vector3(0.45, 2.12, 0.0),
		"swing": 1.25, "swing_chance": 0.85, "inswing": 0.45, "seam": 0.9, "trait": "Swings the new ball both ways"},
	"lf": {"action": "express", "arm": "L", "style": "swing", "label": "LEFT-ARM FAST", "pace": [35.5, 40.0], "release": Vector3(-0.42, 2.2, 0.0),
		"swing": 1.1, "swing_chance": 0.65, "inswing": 0.65, "seam": 0.9, "yorker": 0.10, "trait": "Angle across you and the inswinging yorker"},
	"lfm": {"action": "express", "arm": "L", "style": "swing", "label": "LEFT-ARM SWING", "pace": [33.5, 37.5], "release": Vector3(-0.42, 2.15, 0.0),
		"swing": 1.3, "swing_chance": 0.85, "inswing": 0.65, "seam": 0.8, "trait": "Swings it back in late"},
	"ob": {"action": "finger", "arm": "R", "style": "off", "label": "RIGHT-ARM OFF SPIN", "pace": [22.0, 25.5], "release": Vector3(0.5, 2.05, 0.0),
		"trait": "Drift and turn into you; the arm ball goes on"},
	"lb": {"action": "wrist", "arm": "R", "style": "leg", "label": "RIGHT-ARM LEG SPIN", "pace": [20.5, 24.0], "release": Vector3(0.42, 1.98, 0.0),
		"trait": "Turns away; googly and flipper"},
	"sla": {"action": "finger", "arm": "L", "style": "sla", "label": "LEFT-ARM ORTHODOX", "pace": [21.5, 25.0], "release": Vector3(-0.5, 2.02, 0.0),
		"trait": "Turns away from you; the arm ball skids in"},
	"lws": {"action": "wrist", "arm": "L", "style": "off", "label": "LEFT-ARM WRIST SPIN", "pace": [20.5, 23.5], "release": Vector3(-0.44, 1.98, 0.0),
		"trait": "Turns into you, with a wrong'un that goes away"},
}

## Adds every IPL bowler to the game's bowler profiles, so matches can use them by name.
static func register_bowlers() -> void:
	for code in TEAMS:
		for a: Array in TEAMS[code].attack:
			var p: Dictionary = STYLES[str(a[1])].duplicate(true)
			var q := float(a[2])
			# Better bowlers are a bit quicker and a bit more skilful with the ball.
			p.pace = [float(p.pace[0]) * (0.95 + 0.05 * q), float(p.pace[1]) * (0.95 + 0.05 * q)]
			if p.has("swing"):
				p.swing = float(p.swing) * (0.8 + 0.3 * q)
			BowlerProfile.EXTRA[str(a[0])] = p

## Day games: the first of two matches on the same date.
static func day_game(f: Dictionary) -> bool:
	if str(f.stage) != "League":
		return false
	for g: Array in FIXTURES:
		if str(g[1]) == str(f.date) and int(g[0]) == int(f.n) + 1:
			return true
	return false

static func team(code: String) -> Dictionary:
	return TEAMS[code]

static func xi_names(code: String) -> Array:
	var out := []
	for p: Array in TEAMS[code].xi:
		out.append(str(p[0]))
	return out

static func attack_names(code: String) -> Array:
	var out := []
	for a: Array in TEAMS[code].attack:
		out.append(str(a[0]))
	return out

## How strong a side is with the bat (top seven) and the ball (its five), 0..1.
static func batting_strength(code: String) -> float:
	var s := 0.0
	var xi: Array = TEAMS[code].xi
	for i in 7:
		s += (float(xi[i][2]) + float(xi[i][3])) * 0.5
	return s / 7.0

static func bowling_strength(code: String) -> float:
	var s := 0.0
	for a: Array in TEAMS[code].attack:
		s += float(a[2])
	return s / 5.0
