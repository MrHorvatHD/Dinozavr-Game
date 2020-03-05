#define gameFieldArrayLen 16
#define gameFieldArrayHei 2
#define gameFieldArraySize gameFieldArrayLen*gameFieldArrayHei
#define jumpTickLen 3
#define minCactDistStart 5
#define halfTickStartSpeed 250

#define rndMulNum 3
#define rndModNum 31

#define dinoChar 0
#define dinoDeadChar 2
#define cactChar 1

.include "m128def.inc"

.def TEMP = R16
.def TEMP2 = R17
.def DelayL = R20
.def jumpTickCount = R21

.dseg
	gameField: .byte gameFieldArraySize
	rndMemSpace: .byte 1
	halfTickSpeed: .byte 1
	minCactDist: .byte 1

.cseg
	;init stack
	ldi TEMP, LOW(RAMEND)
	out SPL, TEMP
	ldi TEMP, HIGH(RAMEND)
	out SPH, TEMP

	;port inicialization
	ldi TEMP, 0b1000_0000
	out DDRD, TEMP

	ldi TEMP, 0b0001_1111
	sts DDRG, TEMP

	ldi TEMP, 1
	out DDRC, TEMP

	ldi DelayL, 50
	rcall delay_nms
	
	;setup before start
	rcall displayInit
	rcall fontCreation
	rcall gameFieldReset
	rcall resetScoreBoard
	rcall gameSpeedInit
	rcall minCactDistInit
	
	rcall startScreen
	rcall randomInit
	
	;start dino position
	ldi r23, dinoChar
	ldi r24, 3
	ldi r25, 1
	rcall fieldSetXY
	clr jumpTickCount

	lds DelayL, halfTickSpeed
	rcall delay_nms
	lds DelayL, halfTickSpeed
	rcall delay_nms
	
	rcall renderDisplay

mainGameLoop:

	rcall dinoJump
	
	;debug
	/*lds TEMP, minCactDist
	ldi r23, '0'
	add r23, TEMP 
	ldi r24, 0
	ldi r25, 0
	rcall fieldSetXY*/
	;end debug

	rcall doScoreBoard
	rcall shiftBotRow
	rcall renderDisplay
	
	lds DelayL, halfTickSpeed
	rcall delay_nms
	lds DelayL, halfTickSpeed
	rcall delay_nms

	rcall gameStateChanges

	rjmp mainGameLoop

;game over screen
;--------------------------------------
gameOver:
	ldi r23, dinoDeadChar
	ldi r24, 3
	ldi r25, 1
	rcall fieldSetXY

	ldi r23, ' '
	ldi r24, 3
	ldi r25, 0
	rcall fieldSetXY
	
	rcall renderDisplay
	
	ldi DelayL, 250
	rcall delay_nms
	ldi DelayL, 250
	rcall delay_nms

	ldi r24, 0x01
	rcall displayCommand
	ldi r24, 0x87
	rcall displayCommand
	ldi r24, 'G'
	rcall displayData
	ldi r24, 'G'
	rcall displayData

	;shift to new line and display "score: "
	ldi r24, 0xC2
	rcall displayCommand
	ldi r24, 'S'
	rcall displayData
	ldi r24, 'c'
	rcall displayData
	ldi r24, 'o'
	rcall displayData
	ldi r24, 'r'
	rcall displayData
	ldi r24, 'e'
	rcall displayData
	ldi r24, ':'
	rcall displayData
	ldi r24, ' '
	rcall displayData

	;display current score
	ldi r24, 11
	ldi r25, 0
	rcall fieldGetXY
	mov r24, r23
	rcall displayData
	ldi r24, 12
	ldi r25, 0
	rcall fieldGetXY
	mov r24, r23
	rcall displayData
	ldi r24, 13
	ldi r25, 0
	rcall fieldGetXY
	mov r24, r23
	rcall displayData
	ldi r24, 14
	ldi r25, 0
	rcall fieldGetXY
	mov r24, r23
	rcall displayData
	ldi r24, 15
	ldi r25, 0
	rcall fieldGetXY
	mov r24, r23
	rcall displayData
		
gameOverLoop:
	rjmp gameOverLoop

;makes the game harder as it progresses
;-----------------------------------------------------------------------
gameStateChanges:

	;every 5 score speed up game tick speed by 2, min tick speed 50ms
	rcall gameSpeedup

	;every 200 score recue distance by 1, min distance 3
	rcall reduceCactusDistance

	ret

;speed up the game tick length
;-----------------------------------------------------------------------
gameSpeedup:
	ldi r24, 15
	ldi r25, 0
	rcall fieldGetXY

	;speed up if score divisible by 5
	mov TEMP, r23
	subi TEMP, '0'
	ldi r24, 5
	rcall modulo

	cpi r23, 0
	brne dontSpeedup

	lds TEMP, halfTickSpeed
	cpi TEMP, 26
	brlo dontSpeedup

	dec TEMP
	sts halfTickSpeed, TEMP

dontSpeedup:
	ret

;helper to reach gameOver with breq
;-----------------------------------------------------------------------
gameOverHeplToReach:
	rjmp gameOver

;reduces the distance between cactuses
;------------------------------------------------------------------------
reduceCactusDistance:
	lds TEMP, minCactDist
	cpi TEMP, 4
	brsh testReduction

	ret

testReduction:
	ldi r24, 13
	ldi r25, 0
	rcall fieldGetXY

	;reduce the distance every 200 score, min dist = 3
	mov TEMP, r23
	cpi TEMP, '2'
	breq cactReduce1

	cpi TEMP, '4'
	breq cactReduce2

	ret

cactReduce1:
	ldi TEMP, 4
	sts minCactDist, TEMP
	ret

cactReduce2:
	ldi TEMP, 3
	sts minCactDist, TEMP
	ret

;checks if dino can jump and executes it or times dinos fall 
;------------------------------------------------------------------------
dinoJump:
	cpi jumpTickCount, 0
	brne skipJumping

	sbis PINC, 0
	rcall doJump
	ret

skipJumping:

	dec jumpTickCount
	cpi jumpTickCount, 0
	breq fallDown

	ret

;handles dino jumping
;-----------------------------------
doJump:
	ldi jumpTickCount, jumpTickLen
	
	ldi r23, ' '
	ldi r24, 3
	ldi r25, 1
	rcall fieldSetXY

	ldi r23, dinoChar
	ldi r24, 3
	ldi r25, 0
	rcall fieldSetXY

	ret

;handles dino falling back down
;------------------------------------
fallDown:
	;detect cactus under
	ldi r24, 3
	ldi r25, 1
	rcall fieldGetXY
	cpi r23, cactChar
	breq gameOverHeplToReach

	ldi r23, dinoChar
	ldi r24, 3
	ldi r25, 1
	rcall fieldSetXY

	ldi r23, ' '
	ldi r24, 3
	ldi r25, 0
	rcall fieldSetXY

	ret

;shifts elements on the bottom row to the left by one, keeps the dinosaur
;---------------------------------------------------------------------------
shiftBotRow:
	
	;remove dino, ignore cactus
	ldi r24, 3
	ldi r25, 1
	rcall fieldgetXY
	cpi r23, cactChar
	breq skipRemoveDino

	ldi r23, ' '
	ldi r24, 3
	ldi r25, 1
	rcall fieldSetXY
skipRemoveDino:

	ldi r19, gameFieldArrayLen-1
	ldi TEMP2, 1
shiftBotRow_for1:
	
	mov r24, TEMP2
	ldi r25, 1
	rcall fieldGetXY

	dec TEMP2
	mov r24, TEMP2
	ldi r25, 1
	rcall fieldSetXY

	inc TEMP2
	inc TEMP2

	dec r19
	cpi r19, 0
	brne shiftBotRow_for1

	;check for dino in air for colision with cactus
	cpi jumpTickCount, 0
	brne noCactusColision

	;check for cactus colision
	ldi r24, 3
	ldi r25, 1
	rcall fieldgetXY
	cpi r23, cactChar
	brne noCactusColision
	
	;colision with cacuts
	rcall gameOver

noCactusColision:
	
	;put dino back, ignore if dino in air
	ldi r24, 3
	ldi r25, 0
	rcall fieldgetXY
	cpi r23, dinoChar
	breq skipPutDinoBack
	
	ldi r23, dinoChar
	ldi r24, 3
	ldi r25, 1
	rcall fieldSetXY

skipPutDinoBack:
	rcall addCactus
	
	ret

;TODO
;adds a cactus to the end of the game field
;--------------------------------------------
addCactus:

	rcall testCactusDistance
	lds TEMP, minCactDist
	cp r23, TEMP
	brlo noCactus

	rcall randomizer

	cpi r23, 10
	brsh noCactus

	cpi r23, 5
	brlo dualCactus
	
	ldi r23, cactChar
	ldi r24, 15
	ldi r25, 1
	rcall fieldSetXY

	ret

dualCactus:
	ldi r23, cactChar
	ldi r24, 15
	ldi r25, 1
	rcall fieldSetXY

	ldi r23, cactChar
	ldi r24, 14
	ldi r25, 1
	rcall fieldSetXY

	ret

		
noCactus:
	ldi r23, ' '
	ldi r24, 15
	ldi r25, 1
	rcall fieldSetXY
	
	ret

;tests for minCactDist
;--------------------------------------------
testCactusDistance:
	ldi TEMP2, 14
	clr r22

testCactusDistance_for1:
	mov r24, TEMP2
	ldi r25, 1
	rcall fieldGetXY
	
	cpi r23, ' '
	brne noSpace
	inc r22

noSpace:
	lds r18, minCactDist
	ldi TEMP, 15
	sub TEMP, r18

	cp TEMP2, TEMP
	breq testCactusDistance_end

	dec TEMP2
	
	rjmp testCactusDistance_for1


testCactusDistance_end:
	mov r23, r22
	ret

;initializes randomizer
;-------------------------------------------
randomInit:
	sts rndMemSpace, r23
	ret

;randomisation function (lehmer congruential generator)
;----------------------------------------------
randomizer:
	;seed = (seed*rndMulNum + 1) % rndModNum
	lds TEMP, rndMemSpace
	ldi TEMP2, rndMulNum
	mul TEMP, TEMP2
	
	mov TEMP, r0

	ldi r24, rndModNum
	rcall modulo

	sts rndMemSpace, TEMP

	ret

;initializes the game tick speed
;--------------------------------------------------
gameSpeedInit:
	ldi TEMP, halfTickStartSpeed
	sts halfTickSpeed, TEMP
	ret

;initializes the game tick speed
;--------------------------------------------------
minCactDistInit:
	ldi TEMP, minCactDistStart
	sts minCactDist, TEMP
	ret

;reset the score board to 0 
;--------------------------------------
resetScoreBoard:

	ldi r23, '0'
	ldi r24, 11
	ldi r25, 0
	rcall fieldSetXY
	ldi r23, '0'
	ldi r24, 12
	ldi r25, 0
	rcall fieldSetXY
	ldi r23, '0'
	ldi r24, 13
	ldi r25, 0
	rcall fieldSetXY
	ldi r23, '0'
	ldi r24, 14
	ldi r25, 0
	rcall fieldSetXY
	ldi r23, '0'
	ldi r24, 15
	ldi r25, 0
	rcall fieldSetXY
	
	ret

;proceses the scoreboard
;x = 10-15, y = 0
;-----------------------------------
doScoreBoard:

	ldi TEMP2, 15

scoreBoardLoop:
	cpi TEMP2, 10
	breq scoreBoardEnd

	mov r24, TEMP2
	ldi r25, 0
	rcall fieldgetXY

	cpi r23, '9'
	breq ScoreBoard_NoCarry1

	inc r23
	mov r24, TEMP2
	ldi r25, 0
	rcall fieldsetXY

scoreBoardEnd:
	ret

ScoreBoard_NoCarry1:
	ldi r23, '0'
	mov r24, TEMP2
	ldi r25, 0
	rcall fieldsetXY

	dec TEMP2
	
	rjmp scoreBoardLoop

;r23 = value, r24 = x, r25 = y
;gameField + y*16 + x
;---------------------------------------------------------------------------
fieldSetXY:
	ldi XH, high(gameField)
	ldi XL, low(gameField)

	;y*16
	lsl r25
	lsl r25
	lsl r25
	lsl r25

	;xh xl + TEMP r25
	clr TEMP
	add xl, r25
	adc xh, TEMP

	;xh xl + TEMP r24
	clr TEMP
	add xl, r24
	adc xh, TEMP

	st x, r23

	ret

;r23 = value, r24 = x, r25 = y
;gameField + y*16 + x
;-----------------------------------------------------------------
fieldGetXY:
	ldi XH, high(gameField)
	ldi XL, low(gameField)

	;y*16
	lsl r25
	lsl r25
	lsl r25
	lsl r25

	;xh xl + TEMP r25
	clr TEMP
	add xl, r25
	adc xh, TEMP

	;xh xl + TEMP r24
	clr TEMP
	add xl, r24
	adc xh, TEMP

	ld r23, x

	ret
	
;displays the game start screen
;---------------------------------------------------------
startScreen:
	;shifts screen by 4
	ldi r24, 0b1000_0100
	rcall displayCommand

	;displays the star screen: "DINOZAVR"
	ldi r24, 'D'
	rcall displayData
	ldi r24, 'I'
	rcall displayData
	ldi r24, 'N'
	rcall displayData
	ldi r24, 'O'
	rcall displayData
	ldi r24, 'Z'
	rcall displayData
	ldi r24, 'A'
	rcall displayData
	ldi r24, 'V'
	rcall displayData
	ldi r24, 'R'
	rcall displayData

	;breaks line and shifts start by 3
	ldi r24, 0b11000011
	rcall displayCommand

	;displays: "Press: IN0"
	ldi r24, 'P'
	rcall displayData
	ldi r24, 'r'
	rcall displayData
	ldi r24, 'e'
	rcall displayData
	ldi r24, 's'
	rcall displayData
	ldi r24, 's'
	rcall displayData
	ldi r24, ':'
	rcall displayData
	ldi r24, ' '
	rcall displayData
	ldi r24, 'I'
	rcall displayData
	ldi r24, 'N'
	rcall displayData
	ldi r24, '0'
	rcall displayData

;wait for in0 press and select the seed
clr r23
wait1:

	inc r23
	mov TEMP, r23
	ldi r24, 31
	rcall modulo

	sbic PINC, 0
	rjmp wait1

	ldi r24, 0x01
	rcall displayCommand

	ret

;sends 8bit command to display
;--------------------------------------------------------
displayCommand:
	;push registers to stack
	push r16
	push r17
	push r18
	push r19
	push r20
	push r21
	push r22
	push r23

	;first nibble of command
	;splits the command in half and sends both nibbles
	mov TEMP, r24

	lsr TEMP
	lsr TEMP
	lsr TEMP
	lsr TEMP
	andi TEMP, 0x0f
	rcall sendCommand

	;second nibble of command
	mov TEMP, r24
	andi TEMP, 0x0f
	rcall sendCommand

	;return register data from stack
	pop r23
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16

	ret

;sends 8bit char data to display
;-------------------------------------------
displayData:
	;push registers to stack
	push r16
	push r17
	push r18
	push r19
	push r20
	push r21
	push r22
	push r23

	;first nibble of letter
	;splits the command for letter in half and sends both nibbles
	mov TEMP, r24

	lsr TEMP
	lsr TEMP
	lsr TEMP
	lsr TEMP
	andi TEMP, 0x0f

	ori TEMP, 0x10
	rcall sendCommand

	;second nibble of letter
	mov TEMP, r24
	andi TEMP, 0x0f

	ori TEMP, 0x10
	rcall sendCommand

	;return register data from stack
	pop r23
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16

	ret

;sends 4bits to display
;--------------------------------------------------
sendCommand:
	sts PORTG, TEMP

	;sets the enable pin on
	ldi TEMP, 0b1000_0000
	out PORTD, TEMP

	ldi DelayL, 1
	rcall delay_nms

	;set the enable pin off
	;LCD proceses the command now
	ldi TEMP, 0b0000_0000
	out PORTD, TEMP

	ldi DelayL, 1
	rcall delay_nms

	ret

;resets the gameField array with ' '
;-------------------------------------------------------
gameFieldReset:
	
	ldi XH, high(gameField)
	ldi XL, low(gameField)
	
	ldi TEMP, ' '
	
	ldi TEMP2, gameFieldArraySize
gameFieldReset_for1:
	st X+, TEMP

	dec TEMP2
	cpi TEMP2, 0
	brne gameFieldReset_for1

	ret

;renders the image on display from memory space (gameField)
;------------------------------------------------------------
renderDisplay:	
	ldi XH, high(gameField)
	ldi XL, low(gameField)
	
	;clear display
	ldi r24, 0x01
	rcall displayCommand

	;display first line
	ldi TEMP, gameFieldArrayLen
renderDisplay_for1:
	ld r24, X+
	rcall displayData

	dec TEMP
	cpi TEMP, 0
	brne renderDisplay_for1

	;set cursor to start of second line
	ldi r24, 0xC0
	rcall displayCommand

	;display second line
	ldi TEMP, gameFieldArrayLen
renderDisplay_for2:
	ld r24, X+
	rcall displayData

	dec TEMP
	cpi TEMP, 0
	brne renderDisplay_for2

	ret

;initialization of display
;---------------------------------------------------------------
displayInit:
	;to send a letter PORTG = xxx1_xxxx and a command xxx0_xxxx

	;3x send 0x03
	ldi TEMP, 0b0000_0011
	rcall sendCommand
	ldi TEMP, 0b0000_0011
	rcall sendCommand
	ldi TEMP, 0b0000_0011
	rcall sendCommand

	;init 4bit
	;for 4bit communication we need to send the command it two parts
	;first the upper 4 bits and then the lower 4

	;8bit command to tell the display we will interface with 4bits
	ldi TEMP, 0b0000_0010
	rcall sendCommand

	;setting datalen to 4bits, 2line display and the char font to 5x10
	ldi TEMP, 0b0000_0010
	rcall sendCommand
	;second nibble
	ldi TEMP, 0b0000_1100
	rcall sendCommand

	;display off
	ldi TEMP, 0b0000_0001
	rcall sendCommand
	;second nibble
	ldi TEMP, 0b0000_0000
	rcall sendCommand

	;clear display
	ldi TEMP, 0b0000_0000
	rcall sendCommand
	;second nibble
	ldi TEMP, 0b0000_0001
	rcall sendCommand

	;entry mode set
	;Sets cursor move direction and specifies display shift
	ldi TEMP, 0b0000_0000
	rcall sendCommand
	;second nibble
	ldi TEMP, 0b0000_0110
	rcall sendCommand

	;turn on display and disables cursor and blinking cursor on location
	ldi TEMP, 0b0000_0000
	rcall sendCommand
	;second nibble
	ldi TEMP, 0b0000_1100
	rcall sendCommand

	ret

;creation of custom fonts
;----------------------------------------------
fontCreation:

	;font 1
	;font address
	ldi r24, 0x40
	rcall displayCommand
	;font line by line
	ldi r24, 0x0E
	rcall displayData
	ldi r24, 0x17
	rcall displayData
	ldi r24, 0x1E
	rcall displayData
	ldi r24, 0x1F
	rcall displayData
	ldi r24, 0x18
	rcall displayData
	ldi r24, 0x1F
	rcall displayData
	ldi r24, 0x1A
	rcall displayData
	ldi r24, 0x12
	rcall displayData

	;font 1
	;font address
	ldi r24, 0x48
	rcall displayCommand
	;font line by line
	ldi r24, 0x04
	rcall displayData
	ldi r24, 0x05
	rcall displayData
	ldi r24, 0x15
	rcall displayData
	ldi r24, 0x15
	rcall displayData
	ldi r24, 0x16
	rcall displayData
	ldi r24, 0x0C
	rcall displayData
	ldi r24, 0x04
	rcall displayData
	ldi r24, 0x04
	rcall displayData

	;font 3
	;font address
	ldi r24, 0x50
	rcall displayCommand
	;font line by line
	ldi r24, 0x12
	rcall displayData
	ldi r24, 0x1A
	rcall displayData
	ldi r24, 0x1F
	rcall displayData
	ldi r24, 0x18
	rcall displayData
	ldi r24, 0x1F
	rcall displayData
	ldi r24, 0x1E
	rcall displayData
	ldi r24, 0x17
	rcall displayData
	ldi r24, 0x0E
	rcall displayData

	;set cursor to the front to stop
	ldi r24, 0x80
	rcall displayCommand

	ret

;modulo of a number
;TEMP % r24 = r23 
;----------------------------------
modulo:
	cp TEMP, r24
	brlo modulo_end

	sub TEMP, r24

	rjmp modulo
	
modulo_end:
	mov r23, TEMP

	ret



;DELAY
;-------------------------------------------------------------------

DELAY_NMS:
	push r18
	push r19
	push r20

	nop

LOOP:
	CPI DelayL, 2
	BRLO END

	LDI  r18, 4
FILL:
	DEC  r18
	BRNE FILL
	NOP
	NOP

;------------------------------------------------------------------

END:
	;CPI R21, 0
	CPI DelayL, 0
	BRNE MS

	pop r20
	pop r19
	pop r18

	RET

;------------------------------------------------------------------
MS:
	LDI  r18, 21
	LDI  r19, 191

L1:
	DEC  r19
	BRNE L1
	DEC  r18
	BRNE L1
	NOP
	NOP

	DEC DelayL
	RJMP LOOP