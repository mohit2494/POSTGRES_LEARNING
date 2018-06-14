CREATE TABLE LOGS ( 
	LOG_ID SERIAL PRIMARY KEY,
	USER_NAME VARCHAR(50),
	DESCRIPTION TEXT,
	LOG_TS TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IDX_LOGS_LOG_TS ON LOGS USING BTREE (LOG_TS);


-- SERIAL IS THE DATA TYPE USED TO REPRESENT AN INCREMENTING AUTONUMBER. 
-- ADDING A SERIAL COLUMN AUTOMATICALLY ADDS AN ACCOMPANYING SEQUENCE OBJECT TO THE DATABASE SCHEMA.
-- A SERIAL DATA TYPE IS ALWAYS AN INTEGER WITH THE DEFAULT VALUE SET TO THE NEXT VALUE OF THE SEQUENCE OBJECT. EACH TABLE USUALLY HAS JUST ONE SERIAL COLUMN, WHICH OFTEN SERVES AS THE PRIMARY KEY.
-- VARCHAR IS SHORTHAND FOR CHARACTER VARYING, A VARIABLE-LENGTH STRING SIMILAR TO WHAT YOU WILL FIND IN OTHER DATABASES. YOU DON’T NEED TO SPECIFY A MAXIMUM LENGTH; IF YOU DON’T, VARCHAR IS ALMOST IDENTICAL TO THE TEXT DATA TYPE.
-- TEXT IS A STRING OF INDETERMINATE LENGTH. IT’S NEVER FOLLOWED BY A LENGTH RESTRICTION.
-- TIMESTAMP WITH TIME ZONE (SHORTHAND TIMESTAMPTZ) IS A DATE AND TIME DATA TYPE, ALWAYS STORED IN UTC. IT ALWAYS DISPLAYS DATE AND TIME IN THE SERVER’S OWN TIME ZONE UNLESS YOU TELL IT TO OTHERWISE

-- THE CONCEPT OF INHERTIANCE IN POSTGRES
-----------------------------------------
/*
	POSTGRESQL STANDS ALONE AS THE ONLY DATABASE OFFERING INHERITED TABLES. 
	WHEN YOU SPEC‐ IFY THAT A TABLE (THE CHILD TABLE) INHERIT FROM ANOTHER 
	TABLE (THE PARENT TABLE), POSTGRESQL CREATES THE CHILD TABLE WITH ITS 
	OWN COLUMNS PLUS ALL THE COLUMNS OF THE PARENT TABLE(S). POSTGRESQL WILL 
	REMEMBER THIS PARENT-CHILD RELATIONSHIP SO THAT ANY STRUCTURAL CHANGES 
	LATER MADE TO THE PARENT AUTOMATICALLY PROPAGATE TO ITS CHILDREN. 
	PARENT-CHILD TABLE DE‐ SIGN IS PERFECT FOR PARTITIONING YOUR DATA. WHEN 
	YOU QUERY THE PARENT TABLE, POSTGRESQL AUTOMATICALLY INCLUDES ALL ROWS 
	IN THE CHILD TABLES. NOT EVERY TRAIT OF THE PARENT PASSES DOWN TO THE CHILD. 
	NOTABLY, PRIMARY KEY CONSTRAINTS, UNIQUENESS CONSTRAINTS, AND IN‐ DEXES ARE 
	NEVER INHERITED. CHECK CONSTRAINTS ARE INHERITED, BUT CHILDREN CAN HAVE THEIR 
	OWN CHECK CONSTRAINTS IN ADDITION TO THE ONES THEY INHERIT FROM THEIR PARENTS
*/

-- CREATE TABLE LOGS_2011 . IT INHERITS LOGS TABLE AS A PARENT.
CREATE TABLE LOGS_2011 ( PRIMARY KEY(log_id) ) INHERITS (logs); 

-- CREATE INDEX 
CREATE INDEX IDX_LOGS_2011_LOG_TS ON logs USING btree(log_ts); 

-- PARENT TABLE CONSTRAINTS INHERITED. ADD NEW CONSTRAINT TO CHILD TABLE.
-- CHECK THAT THE LOG BELONGS TO THE YEAR 2011.
ALTER TABLE LOGS_2011 ADD CONSTRAINT CHK_Y_2011
CHECK ( LOG_TS >= '2011-1-1'::TIMESTAMPTZ AND LOG_TS < '2012-1-1'::TIMESTAMPTZ );


-- THE CONCEPT OF UNLOGGED TABLES
---------------------------------

/*
	THE BIG ADVANTAGE OF AN UNLOGGED TABLE IS THAT WRITING DATA TO IT IS MUCH FASTER THAN TO A LOGGED TABLE.
	OUR EXPERIENCE SUGGESTS ON THE ORDER OF 15 TIMES FASTER. 

	KEEP IN MIND THAT YOU’RE MAKING SACRIFICES WITH UNLOGGED TABLES:
		• IF YOUR SERVER CRASHES, POSTGRESQL WILL TRUNCATE ALL UNLOGGED TABLES. (TRUNCATE MEANS ERASE ALL ROWS.)
		• UNLOGGED TABLES DON’T SUPPORT GIST INDEXES (DEFINED IN “POSTGRESQL STOCK IN‐ DEXES” ON PAGE 113). 
		  THEY ARE THEREFORE UNSUITABLE FOR EXOTIC DATA TYPES THAT RELY ON GIST FOR SPEEDY ACCESS.

	UNLOGGED TABLES WILL ACCOMMODATE THE COMMON B-TREE AND GIN, THOUGH.
*/
CREATE UNLOGGED TABLE WEB_SESSIONS ( SESSION_ID TEXT PRIMARY KEY, ADD_TS TIME STAMPTZ, UPD_TS TIMESTAMPTZ, SESSION_STATE XML);

-- CONSTRAINTS
--------------

-- NOT ONLY DO YOU CREATE CONSTRAINTS, BUT YOU CAN ALSO CONTROL ALL FACETS OF HOW A CONSTRAINT HANDLES EXISTING DATA, 
-- ANY CASCADE OPTIONS, HOW TO PERFORM THE MATCHING, WHICH INDEXES TO INCORPORATE, CONDITIONS UNDER WHICH THE CONSTRAINT 
-- CAN BE VIOLATED, AND MORE. ON TOP OF IT ALL, YOU CAN PICK YOUR OWN NAME FOR EACH CONSTRAINT.

-- FOREIGN KEY CONSTRAINTS
--------------------------
-- YOU CAN SPECIFY CASCADE UPDATE AND DELETE RULES TO AVOID PESKY ORPHANED RE-CORDS.

ALTER TABLE FACTS ADD CONSTRAINT FK_FACTS_1 FOREIGN KEY (FACT_TYPE_ID) REFERENCES LU_FACT_TYPES (FACT_TYPE_ID)
ON UPDATE CASCADE ON DELETE RESTRICT;

CREATE INDEX FKI_FACTS_1 ON FACTS (FACT_TYPE_ID);

-- WE DEFINE A FOREIGN KEY RELATIONSHIP BETWEEN OUR FACTS AND FACT_TYPES TABLES.
-- THIS PREVENTS US FROM INTRODUCING FACT TYPES INTO FACTS UNLESS THEY ARE ALREADY PRESENT IN THE FACT TYPES LOOKUP TABLE.
-- WE ADD A CASCADE RULE THAT AUTOMATICALLY UPDATES THE FACT_TYPE_ID IN OUR FACTS TABLE SHOULD WE RENUMBER OUR FACT TYPES. 
-- WE RESTRICT DELETES FROM OUR LOOKUP TABLE SO FACT TYPES IN USE CANNOT BE REMOVED. 
-- RESTRICT IS THE DEFAULT BEHAVIOR, BUT WE SUGGEST STATING IT FOR CLARITY.
-- UNLIKE FOR PRIMARY KEY AND UNIQUE CONSTRAINTS, POSTGRESQL DOESN’T AUTOMATICALLY CREATE AN INDEX FOR FOREIGN KEY CONSTRAINTS; YOU SHOULD ADD THIS YOURSELF TO SPEED UP QUERIES.


-- UNIQUE CONSTRAINTS
---------------------
-- EACH TABLE CAN HAVE NO MORE THAN A SINGLE PRIMARY KEY. IF YOU NEED TO ENFORCE UNIQUENESS ON OTHER COLUMNS, YOU MUST RESORT TO UNIQUE CONSTRAINTS OR UNIQUE INDEXES.
-- ADDING A UNIQUE CONSTRAINT AUTOMATICALLY CREATES AN ASSOCIATED UNIQUE INDEX. SIMILAR TO PRIMARY KEYS, UNIQUE KEY CONSTRAINTS CAN PARTICIPATE IN REFERENCES PART OF 
-- FOREIGN KEY CON‐ STRAINTS AND CANNOT HAVE NULL VALUES.
-- A UNIQUE INDEX WITHOUT A UNIQUE KEY CONSTRAINT DOES ALLOW NULL VALUES.
-- THE FOLLOWING EXAMPLE SHOWS HOW TO ADD A UNIQUE INDEX:

ALTER TABLE LOGS_2011 ADD CONSTRAINT UQ UNIQUE (USER_NAME,LOG_TS);

-- CHECK CONSTRAINTS
--------------------
-- CHECK CONSTRAINTS ARE CONDITIONS THAT MUST BE MET FOR A FIELD OR A SET OF FIELDS FOR EACH ROW. 
-- THE QUERY PLANNER CAN ALSO TAKE ADVANTAGE OF CHECK CONSTRAINTS AND ABANDON QUERIES THAT DON’T 
-- MEET THE CHECK CONSTRAINT OUTRIGHT.

-- ADDING A SAMPLE CHECK CONSTRAINT
-----------------------------------
ALTER TABLE LOGS ADD CONSTRAINT CHK CHECK (USER_NAME = LOWER(USER_NAME))); -- CONSTRAINTS ALL USER NAMES TO BE IN LOWER CASE.

-- EXCLUSION CONSTRAINTS
------------------------
-- EXCLUSION CONSTRAINTS ALLOW YOU TO INCORPORATE ADDITIONAL OPERATORS TO ENFORCE UNIQUENESS THAT CAN’T BE SATISFIED BY THE 
-- EQUALITY OPERATOR. EXCLUSION CONSTRAINTS ARE ESPECIALLY USEFUL IN PROBLEMS INVOLVING SCHEDULING.

-- PREVENT OVERLAPPING BOOKINGS FOR THE SAME ROOM.

CREATE TABLE SCHEDULES(
	ID SERIAL PRIMARY KEY,
	ROOM SMALLINT, 
	TIME_SLOT TSTZRANGE
); 

ALTER TABLE schedules ADD CONSTRAINT EX_SCHEDULES
EXCLUDE USING GIST (ROOM WITH =, TIME_SLOT WITH &&);

-- INDEXES 
----------
-- POSTGRESQL SHIPS STOCKED WITH A LAVISH FRAMEWORK FOR CREATING AND FINE-TUNING INDEXES. 
-- THE ART OF POSTGRESQL INDEXING COULD FILL A TOME ALL BY ITSELF. AT THE TIME OF WRITING, 
-- SPOSTGRESQL COMES WITH AT LEAST FOUR TYPES OF INDEXES, OFTEN REFERRED TO AS INDEX METHODS.
-- IF YOU FIND THESE INSUFFICIENT, YOU CAN DEFINE NEW INDEX OPERATORS AND MODIFIERS TO SUPPLEMENT
-- THEM. IF STILL UNSATISFIED, YOU’RE FREE TO INVENT YOUR OWN INDEX TYPE.

-- POSTGRESQL ALSO ALLOWS YOU TO MIX AND MATCH DIFFERENT INDEX TYPES IN THE SAME TABLE WITH THE 
-- EXPECTATION THAT THE PLANNER WILL CONSIDER THEM ALL. FOR INSTANCE, ONE COLUMN COULD USE A B-TREE 
-- INDEX WHILE AN ADJACENT COLUMN USES A GIST INDEX, WITH BOTH INDEXES CONTRIBUTING TO THE SPEED OF THE QUERY.

-- THERE ARE 4 TYPES OF INDEXES IN POSTGRES SQL
-- BTREE 
/*
	B-TREE IS A GENERAL-PURPOSE INDEX COMMON IN RELATIONAL DATABASES. YOU CAN USUALLY GET BY WITH B-TREE ALONE 
	IF YOU DON’T WANT TO EXPERIMENT WITH ADDITIONAL TYPES. IF POSTGRESQL AUTOMATICALLY CREATES AN INDEX FOR YOU
	OR YOU DON’T BOTHER SPECIFYING THE INDEX METHOD, B-TREE WILL BE CHOSEN. IT IS CURRENTLY THE ONLY INDEX METHOD
	FOR PRIMARY KEYS AND UNIQUE KEYS.
*/
-- GIST
-- GIN
-- SP-GIST
-- HASH
-- B-TREE-GIST / B-TREE-GIN


/*** MULTI COLUMN INDEXES ***/
CREATE INDEX <INDEX-NAME> ON <TABLE-NAME> USING BTREE(COL1,COL2..,COLN);

**** READ MORE ABOUT INDEXES FROM WEB ****



