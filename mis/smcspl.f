      SUBROUTINE SMCSPL ( MCOL, ZI )
C      
C SMCSPL RETRIEVES COLUMN "MCOL" FROM THE SPILL FILE.
C IF THIS COLUMN IS THE PIVOT COLUMN AND NO SPACE IS AVAILABLE, THEN
C IN-MEMORY DATA WILL BE WRITTEN TO THE SPILL FILE TO MAKE SPACE
C AVAILABLE FOR THE COLUMN DATA.  IF THE COLUMN IS NOT THE PIVOT 
C COLUMN, THEN THE DATA IS READ INTO THE SPILL ARRAY IN OPEN CORE.
C WHEN A NEW PIVOT COLUMN IS DETERMINED, AN ANALYSIS IS DONE TO
C FREE UP MEMORY OF COLUMN DATA NO LONGER NEEDED.
C
      INTEGER          ZI(10), ITEMP(4)
      INCLUDE  'SMCOMX.COM'
      CHARACTER    UFM*23, UWM*25, UIM*29, SFM*25
      COMMON / XMSSG / UFM, UWM, UIM, SFM
      MDIR = (MCOL-1)*4 + 1
C
C POSITION SPILL FILE TO CORRECT RECORD FOR THIS COLUMN AND READ DATA
C
      CALL FILPOS ( ISCR1, ZI( MDIR+3 ) )
      CALL READ ( *7001, *7002, ISCR1, ZI( ISPILL ), 4, 0, 4 )  
      MM2    = ZI( ISPILL+1 )
      MTERMS = ZI( ISPILL+3 )
      MWORDS = MM2 + MTERMS * IVWRDS 
C      PRINT *,' SMCSPL,MM2,MTERMS,MWORDS=',MM2,MTERMS,MWORDS
      CALL READ ( *7001, *7002, ISCR1, ZI( ISPILL+4 ),MWORDS,1,MWORDS ) 
C
C CHECK IF WE HAVE ALREADY SCANNED FOR UNNEEDED COLUMNS FOR THIS PIVOT
C      
C      PRINT *,' SMCSPL,MEMLCK,KCOL=',MEMLCK,KCOL
      IF ( MEMLCK .EQ. KCOL ) GO TO 300
      MEMLCK = KCOL
C
C SCAN FOR COLUMNS NO LONGER NEEDED AND ADD THEM TO THE FREE CHAIN
C      
      IFIRST = 0
      DO 200 I = MEMCOL1, KCOL
      IDIR = (I-1)*4 + 1
C
C CHECK TO SEE IF THIS COLUMN NEEDED BY ANY SUBSEQUENT COLUMNS TO FOLLOW
C
      IF ( ZI( IDIR + 2 ) .GE. KCOL ) GO TO 199
C      
C DATA NO LONGER NEEDED, IS DATA IN MEMORY IF SO FREE THE SPACE TO THE
C FREE CHAIN
C
      IF ( ZI( IDIR     ) .EQ. 0    ) GO TO 200
C       
C DATA IS IN MEMORY, RETURN SPACE TO FREE CHAIN
C FIRST, CHECK IF A FREE CHAIN EXISTS
C
      IF ( MEMFRE .NE. 0 ) GO TO 100
C
C FREE CHAIN DOES NOT EXISTS, MAKE THIS SPACE THE FREE CHAIN      
C
      IIDX   = ZI( IDIR )
      MEMFRE = IIDX
      MEMLAS = IIDX
      ZI( IIDX )   = 0
      ZI( IIDX+1 ) = 0
      ZI( IDIR   ) = 0
      GO TO 200
C
C FREE CHAIN EXISTS, ADD THIS SPACE TO IT
C
100   LIDX   = MEMLAS
      IIDX   = ZI( IDIR )
      MEMLAS = IIDX
      ZI( LIDX+1 ) = MEMLAS
      ZI( IIDX   ) = LIDX
      ZI( IIDX+1 ) = 0
      ZI( IDIR   ) = 0
      GO TO 200
199   IF ( IFIRST .EQ. 0 ) IFIRST = I
200   CONTINUE
      MEMCOL1 = IFIRST
C
C CHECK IF THE FREE CHAIN IS EMPTY
C
300   IF ( MEMFRE .EQ. 0 ) GO TO 1000 
C
C LOOP THROUGH FREE CHAIN TO FIND BLOCK LARGE ENOUGH FOR DATA
C      
      IIDX = MEMFRE
400   CONTINUE
      IF ( ZI( IIDX+2 ) .GE. (MWORDS+4) ) GO TO 500
      IIDX = ZI( IIDX+1 )
      IF ( IIDX .NE. 0 ) GO TO 400
C
C FREE CHAIN EXHAUSTED WITHOUT LARGE ENOUGH BLOCK, MUST CREATE SPACE
C      
C      PRINT *,' SMCSPL GOING TO 1000 FROM 400'
      GO TO 1000
C
C SPACE FOUND, USE THIS FOR THE COLUMN DATA READ FROM THE SPILL FILE.
C RECONNECT FREE CHAIN WITHOUT THIS SPACE
C
500   ZI ( MDIR ) = IIDX
      IPREV  = ZI( IIDX   )
      INEXT  = ZI( IIDX+1 )
C      PRINT *,' SMCSPL,AFTER 500,IPREV,INEXT=',IPREV,INEXT
      IF ( IPREV .NE. 0 ) GO TO 510
      IF ( INEXT .EQ. 0 ) GO TO 505 
      ZI( INEXT ) = 0
      MEMFRE      = INEXT
      GO TO 530
505   MEMFRE = 0
      GO TO 530
510   IF ( INEXT .EQ. 0 ) GO TO 520
C      PRINT *,' SMCSPL,AFTER 510,INEXT,IPREV=',INEXT,IPREV
      ZI( IPREV+1 ) = INEXT
      ZI( INEXT   ) = IPREV
      GO TO 530
520   ZI( IPREV+1 ) = 0
      MEMLAS        = IPREV
C 
C MOVE DATA TO IN MEMORY LOCATION
C
530   CONTINUE
      ZI( MDIR    ) = IIDX
      ZI( MDIR+3  ) = 0   
      ZI( IIDX    ) = MCOL
      ZI( IIDX+1  ) = MM2
      ZI( IIDX+3  ) = MTERMS
      DO 540 J = 1, MWORDS
      ZI( IIDX+J+3 ) = ZI (ISPILL+J+3 )
540   CONTINUE
      MEMCOLN = MCOL
C      PRINT *,' SMCSPL,A540,IIDX,ZI(1-5=',IIDX,(ZI(IIDX+KB),KB=0,4)
      GO TO 7777
C
C NO SPACE FOUND IN MEMORY FOR THIS DATA.
C CHECK IF COLUMN BEING REQUESTED IS THE PIVOT COLUMN
C
 1000 CONTINUE 
C      PRINT *,' SMCSPL,MCOL,KCOL=',MCOL,KCOL
      IF ( MCOL .NE. KCOL ) GO TO 2000 
C
C COLUMN REQUESTED IS THE PIVOT COLUMN, FIRST DETERMINE IF THERE
C ARE CONTIGUOUS BLOCKS IN THE FREE CHAIN THAT CAN BE MERGED TOGETHER
C
      IF ( MEMFRE .EQ. 0 ) GO TO 1400
      INDEX1 = MEMFRE
      INDEXT = MEMFRE
1100  CONTINUE
      INDEX2 = ZI( INDEXT + 1 )
      IF ( INDEX2 .EQ. 0 ) GO TO 1300
C
C COMPUTE THE LAST ADDRESS (PLUS 1) OF THIS FREE BLOCK AND COMPARE
C IT WITH THE BEGINNING OF BLOCK REFERENCED BY VARIABLE "INDEX1"
C      
      IEND   = INDEX2 + ZI( INDEX2 + 2 )
      IF ( IEND .EQ. INDEX1 ) GO TO 1200
C
C BLOCK IS NOT CONTIGUOUS, GO AND TEST NEXT BLOCK IN CHAIN
C
      INDEXT = INDEX2
      GO TO 1100
C 
C BLOCK IS CONTIGUOUS, MERGE THIS BLOCK AND THEN GO BACK TO
C TEST THE FREE CHAIN FOR SPACE FOR THE CURRENT PIVOT COLUMN.
C     EACH FREE CHAIN BLOCK HAS THE FOLLOWING FORMAT FOR THE FIRST 3
C     WORDS: 
C             (1) = Pointer to previous block in chain
C             (2) = Pointer to next block in chain
C             (3) = Number of words in this block
C         (Note: Blocks are allocated from high memory to low:)
C              Memory Address N
C                     Block k
C                     Block k-1
C                        .
C                     Block 1
C              Memory Address N+M
C
1200  CONTINUE
C      PRINT *,' SMCSPL,A1200,INDEX1,INDEX2=',INDEX1,INDEX2
      ZI( INDEX2+2 ) = ZI( INDEX1+2 ) + ZI( INDEX2+2 )
C
C RESET NEXT AND PREVIOUS POINTERS OF CHAIN BLOCKS
C
      INDEXP        = ZI( INDEX1 )
      ZI( INDEX2 )  = INDEXP
      IF ( INDEXP .EQ. 0 ) MEMFRE = INDEX2
      IF ( INDEXP .NE. 0 ) ZI( INDEXP+1 ) = INDEX2
C      PRINT *,' SMCSPL,A1200,MWORDS,ZI(INDEX1+2=',MWORDS,ZI(INDEX1+2)
      IF ( ZI( INDEX2+2 ) .LT. (MWORDS+4) ) GO TO 1000
      IIDX = INDEX2
      GO TO 500
C
C  NO BLOCKS CONTIGUOUS WITH THIS BLOCK, GET NEXT BLOCK IN CHAIN
C  AND CHECK FOR CONTIGUOUS BLOCKS WITH IT.
C
1300  CONTINUE
      INDEX1 = ZI( INDEX1 + 1 )
C
C  FIRST CHECK THAT THERE IS ANOTHER BLOCK IN THE FREE CHAIN
C
      IF ( INDEX1 .EQ. 0 ) GO TO 1400
      INDEXT = MEMFRE
      GO TO 1100
1400  CONTINUE
C
C COLUMN REQUESTED IS THE PIVOT COLUMN, MUST FIND MEMORY TO READ
C THIS DATA INTO.  SEARCH FOR LAST COLUMN IN MEMORY WITH SUFFICIENT
C SPACE AND WRITE THAT COLUMN TO SPILL AND READ THE PIVOT COLUMN DATA
C INTO THE MEMORY THAT BECAME AVAILABLE.
C      
      IDIR   = (MEMCOLN-1) * 4 + 1
      KCOLP1 = KCOL + 1
      DO 1500 I = MEMCOLN, 1, -1
      IF ( I .EQ. KCOL ) GO TO 1500
      IDIR = (I-1)*4 + 1
C
C CHECK TO SEE IF DATA ALREADY ON SPILL FILE
C      
      IF ( ZI( IDIR ) .EQ. 0 ) GO TO 1500
C
C DATA IS IN MEMORY, CHECK TO SEE IF ENOUGH SPACE
C      
      IMIDX = ZI( IDIR )
      IF ( ZI( IMIDX+2 ) .LT. (MWORDS+4) ) GO TO 1500
C
C SUFFICIENT SPACE, WRITE THIS COLUMN DATA TO THE SPILL FILE
C TO MAKE ROOM FOR THE PIVOTAL COLUMN DATA TO BE KEPT IN MEMORY.
C SKIP TO END OF FILE, BACKSPACE OVER EOF, CLOSE AND REOPEN FILE 
C FOR WRITE WITH APPEND.
C      
      CALL DSSEND( ISCR1 )
      CALL SKPREC( ISCR1, -1 )
      CALL CLOSE ( ISCR1,  2 )
      CALL GOPEN ( ISCR1, ZI( IBUF2 ), 3 )
      IM2    = ZI( IMIDX+1 )
      ITERMS = ZI( IMIDX+3 ) 
      LENGTH = IM2 + ITERMS*IVWRDS
      ITEMP( 1 ) = I
      ITEMP( 2 ) = IM2
      ITEMP( 3 ) = 0
      ITEMP( 4 ) = ITERMS
      CALL WRITE ( ISCR1, ITEMP , 4, 0 )
      CALL SAVPOS( ISCR1, KPOS )  
      CALL WRITE ( ISCR1, ZI( IMIDX+4 ), LENGTH, 1 )
      CALL CLOSE ( ISCR1, 3 )
      CALL GOPEN ( ISCR1, ZI( IBUF2 ), 0 )
C 
C SET DIRECTORY AND MOVE DATA INTO MEMORY LOCATION
C
C      PRINT *,' SMCSPL B1450,IMIDX,ISPILL=',IMIDX,ISPILL
      ZI( IDIR    ) = 0
      ZI( IDIR+3  ) = KPOS
      ZI( MDIR    ) = IMIDX
      ZI( MDIR+3  ) = 0
      ZI( IMIDX   ) = MCOL
      ZI( IMIDX+1 ) = MM2
      ZI( IMIDX+3 ) = MTERMS
C      PRINT *,' SMCSPL,B1450,MCOL,MM2,MTERMS=',MCOL,MM2,MTERMS
      DO 1450 J = 1, MWORDS
      ZI( IMIDX+J+3 ) = ZI (ISPILL+J+3 )
1450  CONTINUE
      MEMCOLN = MCOL
C      PRINT *,' SMCSPL,A1450,ZI(1-5=',(ZI(IMIDX+KB),KB=0,4)
      GO TO 7777    
1500  CONTINUE
C
C NONE OF THE EXISTING IN-MEMORY ALLOCATIONS ARE LARGE ENOUGH.
C THEREFORE, MUST MERGE TWO TOGETHER TO TRY AND MAKE ENOUGH SPACE.
C      
      DO 1900 I = MEMCOLN, 1, -1
      IF ( I .EQ. KCOL ) GO TO 1900
      IDIR = ( I-1)*4 + 1
      IF ( ZI( IDIR ) .EQ. 0 ) GO TO 1900
      IMIDX1  = ZI( IDIR )
      ISPACE1 = ZI( IMIDX1+2 )
C      PRINT *,' SMCSPL,B1800,IMIDX1,ISPACE1=',IMIDX1,ISPACE1
      IEND1   = IMIDX1 + ISPACE1
      DO 1800 J = MEMCOLN, 1, -1
      IF ( J .EQ. KCOL ) GO TO 1800
      IF ( J .EQ. I    ) GO TO 1800
      JDIR = ( J-1 ) * 4 + 1
      IF ( ZI( JDIR ) .EQ. 0 ) GO TO 1800
      JMIDX1  = ZI( JDIR )
      ISPACE2 = ZI( JMIDX1+2 )
C      PRINT *,' SMCSPL,I1800,JMIDX1,ISPACE2=',JMIDX1,ISPACE2
      IEND2   = JMIDX1 + ISPACE2
      IF ( IABS( IMIDX1-IEND2 ) .LE. 4 ) GO TO 1700
      IF ( IABS( JMIDX1-IEND1 ) .LE. 4 ) GO TO 1700
      GO TO 1800
C
C COLUMNS J AND I HAVE CONTIGUOUS MEMORY, CHECK IF COMBINED SPACE IS
C LARGE ENOUGH FOR THIS COLUMN
C
1700  ITOTAL = ISPACE1 + ISPACE2
C      PRINT *,' SMCSPL,A1700,ISPACE1,ISPACE2,ITOTAL,MWORDS='
C     &,         ISPACE1,ISPACE2,ITOTAL,MWORDS
      IF ( ITOTAL .LT. (MWORDS+4) ) GO TO 1900
C
C SPACE IS LARGE ENOUGH, SO WRITE COLUMNS I AND J TO SPILL AND MERGE
C THE TWO AREAS TOGETHER.
C SKIP TO END OF FILE, BACKSPACE OVER EOF, CLOSE AND REOPEN FILE 
C FOR WRITE WITH APPEND.
C      
      CALL DSSEND ( ISCR1 )
      CALL SKPREC ( ISCR1, -1 )
      CALL CLOSE  ( ISCR1,  2 )
      CALL GOPEN  ( ISCR1, ZI( IBUF2 ), 3 )
C
C WRITE COLUMN I TO SPILL FILE
C
      IM2        = ZI( IMIDX1+1 )
      ITERMS     = ZI( IMIDX1+3 )
      ILEN       = IM2 + ITERMS*IVWRDS
      ITEMP( 1 ) = I
      ITEMP( 2 ) = IM2
      ITEMP( 3 ) = 0
      ITEMP( 4 ) = ITERMS
C      PRINT *,' SMCSPL WRITING COLUMN I=',I
      CALL WRITE ( ISCR1, ITEMP, 4, 0 )
      CALL SAVPOS( ISCR1, KPOS ) 
      CALL WRITE ( ISCR1, ZI( IMIDX1+4 ), ILEN, 1 )
C      
C RESET DIRECTORY FOR COLUMN I
C
      ZI( IDIR   ) = 0
      ZI( IDIR+3 ) = KPOS
C
C WRITE COLUMN J TO THE SPILL FILE
C
      JM2    = ZI( JMIDX1+1 )
      JTERMS = ZI( JMIDX1+3 )
      JLEN   = 4 + JM2 + JTERMS*IVWRDS
      ITEMP( 1 ) = J
      ITEMP( 2 ) = JM2
      ITEMP( 3 ) = 0
      ITEMP( 4 ) = JTERMS
C      PRINT *,' SMCSPL,WRITING COLUMN J=',J
      CALL WRITE ( ISCR1, ITEMP, 4, 0 )
      CALL SAVPOS( ISCR1, KPOS )
      CALL WRITE ( ISCR1, ZI( JMIDX1+4 ), JLEN, 1 )
C 
C RESET DIRECTORY FOR COLUMN J
C
      ZI( JDIR   ) = 0
      ZI( JDIR+3 ) = KPOS
      CALL CLOSE ( ISCR1, 3 )
      CALL GOPEN ( ISCR1, ZI( IBUF2 ), 0 )
      INDEX = JMIDX1
      IF ( IMIDX1 .LT. JMIDX1 ) INDEX = IMIDX1
C
C MOVE DATA INTO MEMORY LOCATION
C
      PRIN T*,' B1750,INDEX,ISPILL=',INDEX,ISPILL
      ZI( INDEX   ) = MCOL   
      ZI( INDEX+1 ) = MM2
      ZI( INDEX+2 ) = ITOTAL
      ZI( INDEX+3 ) = MTERMS
      ZI( MDIR    ) = INDEX
      ZI( MDIR+3  ) = 0
      DO 1750 K = 1, MWORDS
      ZI( INDEX+K+3 ) = ZI( ISPILL+K+3 )
1750  CONTINUE
      MEMCOLN = MCOL
      GO TO 7777
1800  CONTINUE
1900  CONTINUE
      GO TO 7003
C
C NO SPACE FOUND AND COLUMN IS NOT THE PIVOTAL COLUMN, USE DATA
C FROM SPILL AREA
C
2000  CONTINUE
7777  CONTINUE
C      print *,' smcspl is returning, memfre=',memfre
C      ikb = memfre
C      do 9777 kk = 1, 100
C      if ( ikb .eq. 0 ) go to 9778
C      print *,' free block i,1-3=',kk,(zi(ikb+kb),kb=0,2)
C      ikb = zi( ikb+1 )
C9777  continue
C9778  continue
      RETURN
7001  WRITE ( NOUT, 9001 ) UFM, KCOL
9001  FORMAT(1X, A23,/,' UNEXPECTED END OF FILE FOR COLUMN ',I4
     &,' IN SUBROUTINE SMCSPL')
      IERROR = 3
      GO TO 7070
7002  WRITE ( NOUT, 9002 ) UFM, KCOL
9002  FORMAT(1X, A23,/,' UNEXPECTED END OF RECORD FOR COLUMN ',I4
     &,' IN SUBROUTINE SMCSPL')
      IERROR = 3
      GO TO 7070
7003  WRITE ( NOUT, 9003 ) UFM, KCOL
9003  FORMAT(1X,A23,/,' INSUFFICIENT CORE IN SUBROUTINE SMCSPL FOR'
     &,' SYMMETRIC DECOMPOSITION, COLUMN=',I6)
      IERROR = 1
      GO TO 7070
7070  CALL SMCHLP 
      CALL MESAGE( -61, 0, 0 )
      RETURN
      END