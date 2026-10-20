;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Jeremy Lombaerts
;MA Physics and Asronomy
;Computersystemen: Project - Snake
;File: SNAKE.ASM
;
;DESCRIPTION: This is the main file. It contains the game's most important functions
;and the gameloop.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------




IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "RAND.INC"
INCLUDE "HELPERS.INC"




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Begin data segment. This is where the static variables are declared.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------

DATASEG

;Definition of settings=================================================================
;These constants are defined globally and on top so that it is relatively easy to change
;some minor aspects of the game. Most of these occure in multiple procedures and can
;be changed to suit the player's desires.

;Playing field settings
WINDOWHEIGHT	equ 200			;Dimensions of the window. 
WINDOWWIDTH		equ 320			
BOXBORDER		equ 8			;Dimensions of the field on which snake moves
BOXHEIGHT		equ 160			;WINDOWHEIGHT = 2*BOXOFFSET + 2*BOXBORDER + BOXHEIGHT
BOXWIDTH		equ 280			;WINDOWWIDTH  = 2*BOXOFFSET + 2*BOXBORDER + BOXWIDTH
BOXOFFSET		equ 12			;BOXHEIGHT, BOXWIDTH must be dividable by 4

;Color settings
WALLCOLOR		equ 0ah			;BIOSColor of the wall, flashy green
SNAKECOLOR		equ 0fh			;BIOSColor of the snake, white
FOODCOLOR		equ 0ch			;BIOSColor of the food, red
EATENCOLOR		equ 09h			;BIOSColor of the food once it is eaten, blue
BACKGROUNDCOLOR	equ 00h			;BIOSColor of the background,

;Snake settings
XBEGIN			equ 160			;These are the (x.y) coordinates where the snake 
YBEGIN			equ 100			;will spawn. Must be dividable by 4
LSNAKEBEGIN		equ 5			;The snake's begin length
SNAKESIZE		equ 4			;Dimensions of one snake block. Unit is pixels x pixels
SNAKESPEED		dd 6			;SNAKESPEED and GSNAKE are strictly speaking not 
GSNAKE			dd 5			;constant, but remaind unchanged during gameplay. A 
								;future update could increase these during gameplay to
								;make the game progressively harder


;Definition of constants================================================================
								
;Address of the 64.000 bytes of the VGA memory
VIDEOORIGIN		equ 0a0000h		;The first address of the video memory




;Definition of global variables=========================================================
;Define some string to be used in the programm
WELCOME    		db '                 SNAKE!', 10, 13, '$'
LVL1			db '              1 - CLASSIC', 10, 13, '$'
LVL2			db '              2 - CHECKBOARD', 10, 13, '$'
LVL3			db '              3 - THE CAGE', 10, 13, '$'
SCORETEXT		db '                           Score: ', '$'
GAMEOVER		db '                GAME OVER!', '$'
GAMEOVERSCORE	db '                Score: ', '$'
ENDINSTRUCTION	db ' Q: Quit                    N: New game', '$'

;Define some variables used to hold the snake in memory. All of these are
;(re)initialised in the initialiseScene and iitialiseSnake procedures
XSNAKE			dd 16000 dup(?)	;These arrays containt the (x,y) coordinates of the
YSNAKE			dd 16000 dup(?)	;snake's squares.
BXSNAKE			dd 16000 dup(?)	;Buffer to update the snake
BYSNAKE			dd 16000 dup(?)	;Buffer to update the snake
LSNAKE			dd ?			;Snake's length. Unit: 1 square of SNAKESIZE^2 pixels
HSNAKE			dd ?			;The location of the snake's head in the array
TSNAKE			dd ?			;The location of the snake's tail in the array
SCORE			dw ?			;Var to hold the player's score. Initialised to 0

XFOOD			dd ?			;VAriable holds x coord of the food
YFOOD			dd ?			;Variable holds y coord of the food
FLAGFOOD		db ?			;Flag raised if food is on the field, lowered when eaten
LEVELSELECTION	db ?			;Used to select the level. 



;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Begin stack segment.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------

STACK

        db 10h dup(?)			;Don't need a large stack




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Begin the text segment. This is where the actual code is located.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------

CODESEG

start:
	sti                  		;Set The Interrupt Flag
	cld                     	;Clear The Direction Flag

	push ds						;Make sure ds and es contain the same information
	pop es

    call rand_init				;Initialise the random number generator
	call setVideoMode
	call initialiseGame
	;code never gets here

	
	
	
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: initialiseGame
;DESCRIPTION: This procedure welcomes the user and calls the initialising procedure.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC initialiseGame
	call welcomeScreen
	call playGame
	ret
ENDP initialiseGame




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: welcomeScreen
;DESCRIPTION: This procedure clears the screen and sets a simple welcome screen.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC welcomeScreen 
	USES eax, ecx, edx
	

	;Display some newlines
	mov ecx, 6
	call setNewLines
	mov ecx, 4	

	;Display the game title, some newlines and the level selector
	mov ah, 09h                     ;INT21H, function 09h = Write string to std output
	mov edx, offset WELCOME         ;Message to print
	int 21h                         ;Call DOS functionality
	
	call setNewLines
	mov ecx, 1

	mov edx, offset LVL1        
	int 21h 
	call setNewLines
	 
	mov edx, offset LVL2        
	int 21h  
	call setNewLines
	
	mov edx, offset LVL3        
	int 21h                      

	;Waits for correct key input to select the level
	WSInputLoop:
		mov eax, 0h
		int 16h                
	
		;Check 1 key pressed
		cmp ah, 02h
		jne WSNot1
			mov [LEVELSELECTION], 1
			jmp WSEnd
		WSNot1:
		
		;Check 2 key pressed
		cmp ah, 03h
		jne WSNot2
			mov [LEVELSELECTION], 2
			jmp WSEnd
		WSNot2:
		
		;Check 3 key pressed
		cmp ah, 04h
		jne WSNot3
			mov [LEVELSELECTION], 3
			jmp WSEnd
		WSNot3:
	jmp WSInputLoop
	
	WSEnd:
	ret
ENDP welcomeScreen




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: playGame
;DESCRIPTION: This function initialises the game by calling the initialising procedures
;and then starts the infinite game loop.
;The checkCollision procedure is the only 'way out' of the infinite game loop.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC playGame
	USES ecx
	
	
	;Call initialisers
	call slowDownGame
	call initialiseScene
	call initialiseSnake
	call initialiseLevel
	
	;Make the game loop
	mov ecx, 1	
	gameLoop:
		;Call all procedures
		call checkForInput
		call generateFood
		call checkColision
		call moveSnake
		call slowDownGame
	jmp gameLoop
	
	
	ret
ENDP playGame




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: initialiseScene
;DESCRIPTION: This procedure writes directly to the video card in VGA mode (320x200 px).
;The aim is to build the box needed for snake. Once the inteface is 
;displayed, control goes back to main.
;All dimensions are specified in the data segment. This makes the program a little bit
;more flexible as it is relatively easy to change the size of the box in which the 
;snake can move.
;Input:							Registers modified:
;		global variables			none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC initialiseScene
	USES eax, ebx, ecx, edx, edi
	
		
	;Clear the screen
	call clearScreen
	call clearText
	
	;Draw the vertical delimitation (line by line)
	mov al, WALLCOLOR
	mov edx, 0						;Counter from 0 to number of vertical lines
	mov edi, VIDEOORIGIN+(WINDOWWIDTH*BOXOFFSET);Start drawing at the correct offset
	
	ISVerticalLoop:					;Each loop event handles one vertical
			add edi, BOXOFFSET		
			mov ecx, BOXBORDER
			rep stosb				;rep stosb:
									;for ecx repetitions,
			add edi, BOXWIDTH		;store the value of eax
									;into the memory location pointed at by edi
			mov ecx, BOXBORDER		;and increase edi by 1
			rep stosb
			add edi, BOXOFFSET
			inc edx
			cmp edx, WINDOWHEIGHT - 2*BOXOFFSET	;Check whether the last line that has to        
	jne ISVerticalLoop 							;be drawn, has been reached
	
	
	;Draw the horizontal delimitation (line by line)
	mov edx, 0
	mov edi, VIDEOORIGIN+BOXOFFSET
	
	ISHorizontalLoop:							;Same procedure as in the vertical loop
		mov ebx, edi							;but instead of looping over vertical
		add edi, WINDOWWIDTH*BOXOFFSET			;walls, loop over horizontal walls.
		mov ecx, BOXBORDER						;So do not advance by steps of 1 byte 
		ISManualRepLoop1:						;in video memory, but in steps of 320
			mov [edi], al						;bytes.	
			add edi, WINDOWWIDTH				;Hence why it's not possible to use
			dec ecx								;stosb and need to manually write the 
		jnz ISManualRepLoop1					;loop
			
		add edi, WINDOWWIDTH*BOXHEIGHT
		
		mov ecx, BOXBORDER
		ISManualRepLoop2:
			mov [edi], al
			add edi, WINDOWWIDTH
			dec ecx
		jnz ISManualRepLoop2
		mov edi, ebx							;This instruction goes back to the top
		inc edi									;of the line, and advances one line 
		inc edx									;further
		cmp edx, WINDOWWIDTH - 2*BOXOFFSET - BOXBORDER
	jne ISHorizontalLoop
	
	;Initialise food flag, score and show in th scene
	mov [FLAGFOOD], 0
	mov [SCORE], 0
	mov ah, 09h                     	;AH=09h - Print DOS Message
	mov edx, offset SCORETEXT        	;DS:EDX -> $ Terminated String
	int 21h 
	call writeScore
	
	
	ret
ENDP initialiseScene




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: initialiseSnake
;DESCRIPTION: This procedure initialises the snake to it's begin size and position.
;The snake is build from squares that are SNAKESIZE wide and high. Their color is given
;by SNAKECOLOR.
;It is stored in memory with two double word arrays and three bytes.
;
;The two arrays are used to store the x-, respectively y-coordinates of each 
;of the snake's blocks. 
;The three bytes are:
;LSNAKE, holds the number of blocks the snake has
;HSNAKE, a 'pointer' to the snake's head's coordinates in the arrays
;TSNAKE, a 'pointer' to the snake's tail's coordinates in the arrays
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC initialiseSnake
	USES eax, ebx, ecx, edx
	
	
	;Initialise the snake's parameters
	mov [LSNAKE], LSNAKEBEGIN
	mov [SNAKESPEED], 6
	
	;Set the snake array to 0
	mov ecx, 2000
	ISResetLoop:
		dec ecx
		mov [XSNAKE+ecx*4], 0
		mov [YSNAKE+ecx*4], 0
		mov [BXSNAKE+ecx*4], 0
		mov [BYSNAKE+ecx*4], 0
	jnz ISResetLoop


	;Spawn the snake
	mov ecx, 0								;Loop over the snake's initial size  
	ISSpawnLoop:
		mov [XSNAKE + ecx*4], XBEGIN		;XSNAKE: double word, advance 4 bytes at once
		imul edx, ecx, SNAKESIZE					
		add edx, YBEGIN						;Snake is spawned vertically, x-coord is const
		mov [YSNAKE + ecx*4], edx 			;y-coord starts at y-begin and increases 
		mov eax, [XSNAKE+ecx*4]				;in steps of SNAKESIZE
		mov ebx, [YSNAKE+ecx*4]
		
		mov dl, SNAKECOLOR					;Set the snake's initial color
		call drawSquare						;Actually draw the snake
		inc ecx								;Increase the counter
		cmp ecx, [LSNAKE]					;Make the snake LSNAKE - blocks long to begin
	jne ISSpawnLoop
	
	;Initialise the snake's tail pointer
	mov eax, [LSNAKE]
	dec eax
	imul eax, 4
	mov [TSNAKE], eax
	mov [HSNAKE], 0
	


	ret
ENDP initialiseSnake




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: initialiseLevel
;DESCRIPTION: This procedure sets the level (classic, checkboard or cage)
;
;Input:							Registers modified:
;		none						none						
;				
;Output:							
;		none						
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC initialiseLevel
	USES eax
	
	
	;Set the desired level
	mov al, [LEVELSELECTION]
	cmp al, 1
	je ILLvlOk
	cmp al, 2
	jne ILLvl3
		call slowDownGame
		call generateCheckboard	
		jmp ILLvlOk
	ILLvl3:
		cmp al, 3
		jne ILLvlOk
		call slowDownGame
		call generateCage
		jmp ILLvlOk				
	ILLvlOk:
	
	
	ret
ENDP initialiseLevel




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: drawSquare(x,y)
;DESCRIPTION: This procedure is used to draw squares of SNAKESIZE dimensions at given 
;coordinates. It is called to draw the snake, to update the snake and to draw the food.
;This procedure is called often so it should be fast and reliable. Minimise read/write!
;
;CONSTRAINT: Because stosw is used (a little bit faster), 
;SNAKESIZE must be a multiple of 2.
;Input:							Registers modified:
;		eax: x coord					none
;		ebx: y coord			
;		dl: color
;				
;Output:							
;		none						
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC drawSquare
	USES ebx, ecx
	
	
	;Compute the offset of the square where (eax,ebx) = (x,y)
	;offset = x+320*y
	imul ebx, 320					;ebx contained y-coord, now 320*y-coord
	add ebx, eax					;eax contains x-coord, ebx now containt offset
	add ebx, VIDEOORIGIN			;Start at the top-left corner of the square
	
	mov ch, SNAKESIZE				;Square is SNAKESIZE high
	mov cl, SNAKESIZE				;Square is SNAKESIZE large
	DSOuterLoop:					;Loop over square's hight
		DSInnerLoop:				;Loop over square's width
			mov [ebx], dl			;Move correct color to video memory
			inc ebx					;Move horizontally forward in video memory
			dec cl					;Decrease counter
		jnz DSInnerLoop
		mov cl, SNAKESIZE			
		add ebx, WINDOWWIDTH - SNAKESIZE
		dec ch
	jnz DSOuterLoop
		
											
	ret
ENDP drawSquare




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: checkForInput
;DESCRIPTION: This procedure checks whether the user has input a change of direcion.
;This procedure simply checks the keyboard buffer, reads it's content, updates the 
;direction if needed and flushes the buffer.
;If the buffer is empty, nothing happens and snake continues in the same direction.
;If the input is invalid, nothing happens either.
;It also prevents snake from going in the opposite direction it is currently going.
;Input:							Registers modified:
;		none							ecx
;					
;							
;Output:							
;		ecx: Contains next direction						
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC checkForInput
	USES eax
	
	
	;Switch to keyboard mode
	mov ah, 1					;INT 16H, function 01h = Query keyboard status/preview key
	int 16h						;Call Keyboard services
	jz endDirectionSwitch		;If no key waiting, we're done
	
	xor ah, ah					;If a key is waiting, call service 0 (Get keystroke)
	int 16h						;Do it (this consumes the key and flushes the buffer)


	;Determine which key was pressed and jump to the corresponding code
	cmp ah, 48h					;up key scancode
	je CFIup
	cmp ah, 4dh					;right key scancode
	je CFIright
	cmp ah, 50h					;down key scancode
	je CFIdown
	cmp ah, 4bh					;left key scancode
	je CFIleft
	cmp ah, 10h					;q key scancode
	je CFIq
	cmp ah, 19h
	je CFIp
	jmp endDirectionSwitch		;key pressed does nothing
	
	
	;Corresponding code
	CFIup:						;Up key pressed
		cmp ecx, 3				;Check current direction is not the opposite of requested
		je endDirectionSwitch	;direction. Prevents snake from going backwards.
		mov ecx, 1				;Change direction
		jmp endDirectionSwitch
	
	CFIright:
		cmp ecx, 4
		je endDirectionSwitch
		mov ecx, 2
		jmp endDirectionSwitch
	
	CFIdown:
		cmp ecx, 1
		je endDirectionSwitch
		mov ecx, 3
		jmp endDirectionSwitch
	
	CFIleft:
		cmp ecx, 2
		je endDirectionSwitch
		mov ecx, 4
		jmp endDirectionSwitch
		
	CFIq:
		call gameOver
		jmp endDirectionSwitch
		
	CFIp:
			 	CFPauseLoop:
			mov eax, 0h
			int 16h                
	
			;Check q key pressed
			cmp ah, 19h
			jne CFPauseLoop
		jmp endDirectionSwitch
	
	endDirectionSwitch:
	
	
	ret
ENDP checkForInput




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: generateFood 
;DESCRIPTION: This procedure is responsible for generating food for the snake. It uses
;the computer's clock to generate pseudo-random coordinates, confined within the playing
;field. The randomness is rather poor, but sufficient for a very simple game. 
;There exists many RNG that could've been copied or re-implemented...
;Input:							Registers modified
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC generateFood
	USES eax, ebx, ecx, edx
	
	
	;Check if there's already food on the field and if so, skip procedure
	cmp [FLAGFOOD], 1
	je GFEnd

	;If there's no food, generate a random number that will be the offset
	;of the food in the video memory, and convert to (x,y) coordinates
   	call rand
   	
	xor edx, edx		;set edx to 0 
   	mov ecx, 64000  	;Divide the random number by 64000 (there are 64000 pixels)
   	div ecx       		;eax contains quotient, edx contains remainder (edx in [0, 63999])
	
	mov eax, edx		;eax is the random offset	
	xor edx, edx		;set edx to 0
	mov ecx, 320		;divide by 320 to convert the offset to 2 coordinates
	div ecx				;edx contains remainder of division (=x-coord)
						;eax contains the quotient (=y coord) 
	push edx			;Need to take each coordinate and divide it by SNAKESIZE
	xor edx, edx		;and multiply the quotient, without the residual, with SNAKESIZE.
	mov ecx, SNAKESIZE	;This ensures that the food blocks are located on one block unit
	div ecx				;on the playing field.
	imul eax, SNAKESIZE
	mov ebx, eax		;ebx now contains y-coord that is an entire multiple of SNAKESIZE
	
	pop eax				;Retrieve what was edx from the stack. This contains the remainder
	xor edx, edx		;from the division, or the x-coordinate.
	mov ecx, SNAKESIZE	;Divide the x-coord with the SNAKESIZE, and multiply the quotient
	div ecx				;of the division with SNAKESIZE.
	imul eax, SNAKESIZE	;eax now contains y-coord that is an entire multiple of SNAKESIZE
	
	
	;Check that the generated coordinates are within the field boundary's
	cmp eax, 0+BOXBORDER+BOXOFFSET				;leftBorder < x
	jl GFEnd
	cmp eax, 320-BOXBORDER-BOXOFFSET-SNAKESIZE	;x < right border
	jg GFEnd
	cmp ebx, 0+BOXBORDER+BOXOFFSET				;upper border < y
	jl GFEnd
	cmp ebx, 200-BOXBORDER-BOXOFFSET-SNAKESIZE	;y < lower border
	jg GFEnd
	
	;Check that the food coordinates are not located on the snake.
	;by comparing the generated coordinates with the snake coordinates
	mov ecx, [LSNAKE]
	GFBiteLoop:
		dec ecx
		mov edx, [XSNAKE+ecx*4]
		cmp edx, eax
		jne GFCheckNext
			;edx = ecx (next x-coord is equal to an older x-coordinate)
			mov edx, [YSNAKE+ecx*4]
			cmp edx, ebx
			jne GFCheckNext
				;edx = ebx (next y-coord is equal to an older y-coordinate)
				ret
		GFCheckNext:
		cmp ecx, 0
	jne GFBiteLoop
	
	;Check that the food coordinates are not located in an obstacle by 
	;checking the video memory content
	imul edx, ebx, 320
	add edx, eax						;ebx = offset
	add edx, VIDEOORIGIN
	cmp [edx], WALLCOLOR
	je GFEnd
	
	;If all conditions met, generate food
	mov dl, FOODCOLOR
	call drawSquare
	inc [FLAGFOOD]	;Update the food flag so that there is only 1 food on the field
	mov [XFOOD], eax
	mov [YFOOD], ebx
	
	GFEnd:
	ret
ENDP generateFood




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: checkColision
;DESCRIPTION: This procedure checks whether the snake has encountered a wall, bitten
;itself or eaten food.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none	
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC checkColision
	USES eax, ebx, ecx, edx
	
	;Get the snake's head's coordinates
	;Get the offset of the head
	;Check of the block in the next direction is a wall
	;if it is a wall, kill snake
	mov edx, [HSNAKE]
	mov eax, [XSNAKE+edx]				;Contains snake head X coord
	mov ebx, [YSNAKE+edx]				;Contains snake head Y coord
	push eax
	push ebx
	
	;snake's direction stored in ecx
	cmp ecx, 1
		je CAUp
	cmp ecx, 2
		je CARight
	cmp ecx, 3
		je CADown
	cmp ecx, 4
		je CALeft
	
	;Get the coordinates of the square the snake is moving into
	CAUp:
		sub ebx, SNAKESIZE
		jmp CCCompare
	CARight:
		add eax,SNAKESIZE
		jmp CCCompare
	CADown:
		add ebx, SNAKESIZE
		jmp CCCompare
	CALeft:
		sub eax, SNAKESIZE
		jmp CCCompare
		
	;Convert the coordinates to an offset in video memory
	CCCompare:
	imul edx, ebx, 320
	add edx, eax	
	
	;Check whether food was eaten
	cmp dword ptr [XFOOD], eax
	jne CCCheckWall
	cmp dword ptr [YFOOD], ebx
	jne CCCheckWall
		;Food was eaten
		mov [FLAGFOOD], 0
		mov ax, [SCORE]
		add ax, 10
		mov [SCORE], ax
		call updateScore
		call growSnake
	
		pop ebx
		pop eax
		mov dl, EATENCOLOR
		call drawSquare
		ret
		
	;Check whether a wall was hit
	CCCheckWall:
	cmp byte ptr [VIDEOORIGIN+edx], WALLCOLOR
	jne CCCheckBite
		;A wall was hit
		pop ebx
		pop eax
		call gameOver
		ret
		
	;Check whether the snake bit itself
	CCCheckBite:
	mov ecx, [LSNAKE]
	CCBiteLoop:
		dec ecx
		mov edx, [XSNAKE+ecx*4]
		cmp edx, eax
		jne CCCheckNext
			;edx = ecx (next x-coord is equal to an older x-coordinate)
			mov edx, [YSNAKE+ecx*4]
			cmp edx, ebx
			jne CCCheckNext
				;edx = ebx (next y-coord is equal to an older y-coordinate)
				pop ebx
				pop eax
				call gameOver
				ret
		CCCheckNext:
		cmp ecx, 0
	jne CCBiteLoop

	;Get here if the snake didn't hit anything
	CCEnd:				
		pop ebx
		pop eax
		ret
ENDP checkColision




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: growSnake
;DESCRIPTION: This procedure is responsible for increasing the length of the snake. It
;uses the two coordinate arrays (XSNAKE, YSNAKE).
;
;It takes the two arrays with the coordinates, and shifts the values in it so that
;the head of the snake (= 1st coordinates) are the first entries in the arrays.
;After doing that, it updates increases the snake's length and 
;updates the head and tail pointers. The following moveSnake calls will delete the last
;entries in X/YSNAKE, but those contain 0's and will delete nothing. This makes it look
;as if the snake were growing
;
;The major problem with this function is that is needs to copy two possibly rather large
;arrays and it needs to do so twice! It would be a good idea to try figure out another
;way to make the snake grow without having to copy two variable length arrays!
;
;Input:							Registers modified:
;		none		 				none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC growSnake
	USES eax, ebx, ecx, edx
	
	
	mov ecx, 0
	GSShiftLoop:
		;Get the current entry's index
		mov ebx, ecx
		imul ebx, 4
		add ebx, [HSNAKE]			;ebx contains offset of current array entry
		
		;Get the first index larger than the one from the last entry
		mov eax, [LSNAKE]
		imul eax, 4					;eax contains offset of end of snake
		
		;If the current index is larger than the largest allowed index, go to front
		cmp eax, ebx				;If eax (LSNAKE) is larger than ebx (HSNAKE), ok
		jg GSSnakeEntryOk
			sub ebx, eax			;If the current snake entry is outside the array
		GSSnakeEntryOk:				;need to go back to front of array
		
		;Copy the values of the current coordinate entry to the buffers
		mov eax, [XSNAKE+ebx]
		mov [BXSNAKE+ecx*4], eax
		mov eax, [YSNAKE+ebx]
		mov [BYSNAKE+ecx*4], eax
		
		;Keep track of loop
		inc ecx
		cmp ecx, [LSNAKE]
	jl GSShiftLoop 
	
	;Copy the values from the buffer to the coordinate arrays in the correct order
	mov ecx, 0	
	GSCopyLoop:
		mov eax, [BXSNAKE+ecx*4]
		mov [XSNAKE+ecx*4], eax
		mov eax, [BYSNAKE+ecx*4]
		mov [YSNAKE+ecx*4], eax
		inc ecx
		cmp ecx, [LSNAKE]
	jl GSCopyLoop
	
	;Update the head and tail pointers, and increase the length of the snake
	mov [HSNAKE], 0	
	mov eax, [LSNAKE]
	add eax, GSNAKE
	mov [LSNAKE], eax
	dec eax
	imul eax, eax, 4
	mov [TSNAKE], eax


	ret
ENDP growSnake




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: moveSnake
;DESCRIPTION: This procedure is responsible for moving the snake.
;In memory, the snake is saved as:
;- two arrays of coordinates (XSNAKE, YSNAKE)
;- one word containing the snake's length
;- two 'pointers' that holds the location of the snake's first/last block in the arrays
;This structure may appaear overly complicated at first, but such an approach has 
;been chosen to reduce the amount of read-write operations. This function gets called
;a lot and it needs to perform as fast as possible!
;
;This function can easily be modified to advance in steps of 1 pixel. This appears 
;smoother, but I do not like it...
;Input:							Registers modified:
;		ecx: Contains the 				none
;		direction in which
;		the snake must go
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC moveSnake
	USES eax, ebx, ecx, edx, edi


	;Delete the last block of the snake
	mov edx, [TSNAKE]
	mov eax, [XSNAKE+edx]
	mov ebx, [YSNAKE+edx]
	
	mov dl, BACKGROUNDCOLOR
	call drawSquare


	;Advance the head: Get current x and y coords
	mov edx, [HSNAKE]
	mov eax, [XSNAKE+edx]
	mov ebx, [YSNAKE+edx]

	;Check what the next direction is
	cmp ecx, 1					
		je MSUp
	cmp ecx, 2
		je MSRight
	cmp ecx, 3
		je MSDown
	cmp ecx, 4
		je MSLeft
		
	;Compute the new coordinates in function of the old ones and the next direction
	MSUp:						
		sub ebx, SNAKESIZE		
		jmp MSdoMove
	MSRight:
		add eax, SNAKESIZE
		jmp MSdoMove
	MSDown:
		add ebx, SNAKESIZE
		jmp MSdoMove
	MSLeft:
		sub eax, SNAKESIZE
		jmp MSdoMove
		
	;Save the new coordinates 		 
	MSdoMove:					
	mov edx, [TSNAKE]
	mov [XSNAKE+edx], eax
	mov [YSNAKE+edx], ebx
	
	;Draw the new first block
	mov dl, SNAKECOLOR			
	call drawSquare	
	
	
	;Update the head and tail pointers
	mov edi, offset HSNAKE
	mov ecx, 2
	MSPointerLoop:
		mov eax, [edi]			;eax contains value of HSNAKE
		sub eax, 4				;Place pointer one 'value' = 4 bytes closer to begin
		cmp eax, -4				;If head was first entry of array, go to last entry
		jne MSHeadOk
		mov ebx, [LSNAKE]		;Last entry located at LSNAKE - 1
		imul ebx, 4				;32-bit registers: need to substract 4 and not 1
		add eax, ebx			;Found correct offset
		MSHeadOk:
		mov [edi], eax			;Update head/tail pointer
		
		mov edi, offset TSNAKE	;Do the same for the tail pointer
		dec ecx
	jnz MSPointerLoop

	
	ret
ENDP moveSnake





;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: updateScore
;DESCRIPTION: This procedure updates the player's score if the snake has eaten
;some food, and also speeds up the game when certain treshold scores are 
;reached.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC updateScore
	USES eax, ebx, ecx, edx
		
		
	call clearText
	
	;Set the score text
	mov ah, 09h                     	;AH=09h - Print DOS Message
	mov edx, offset SCORETEXT        	;DS:EDX -> $ Terminated String
	int 21h 
		
	;And write the new score
	call writeScore
	
	;If score gets larger than 500, 1000, 1500, 2000, increase speed
	mov ax, [SCORE]
	
	cmp ax, 100
	je USBoost
	cmp ax, 250
	je USBoost
	cmp ax, 500
	je USBoost
	jmp USEnd

	USBoost:
	mov eax, [SNAKESPEED]
	dec eax
	mov [SNAKESPEED], eax
			
	USEnd:	
	ret
ENDP updateScore

	


;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: slowDownGame
;DESCRIPTION: This procedure slows down the game. 
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC slowDownGame
	USES eax, ecx, edx

	mov ecx, SNAKESPEED
	SDGLoop:
		mov dx, 03dah
		@@waitVBlank_wait1:
		in al, dx
		and al, 8
		jnz @@waitVBlank_wait1
		@@waitVBlank_wait2:
		in al, dx
		and al, 8
		jz @@waitVBlank_wait2
		dec ecx
	jnz SDGLoop
	ret
ENDP slowDownGame




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: gameOver
;DESCRIPTION: This procedure quits the game
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC gameOver
	;Clear the screen
	call slowDownGame
	call clearScreen
	
	;Display some newlines
	mov ecx, 11
	call setNewLines

	;Display the game over message
	mov ah, 09h                     	;INT21H, function 09h = Write string to std output
	mov edx, offset GAMEOVER       		;Message to print
	int 21h                         	;Call DOS functionality
	
	;newline
	mov ecx, 1
	call setNewLines
	
	;Score
	mov ah, 09h                     	;AH=09h - Print DOS Message
	mov edx, offset GAMEOVERSCORE      	;DS:EDX -> $ Terminated String
	int 21h 
	call writeScore
	
	;More newlines
	mov ecx, 11
	call setNewLines
	
	mov edx, offset ENDINSTRUCTION        	
	int 21h 
	
	;Waits for any key input to quit or restart
	QGInputLoop:
		mov eax, 0h
		int 16h                
	
		;Check q key pressed
		cmp ah, 10h
		je QGEnd
		
		;Check n key pressed
		cmp ah, 31h
		jne QGInputLoop
		call slowDownGame
		call clearScreen
		call clearText
		call initialiseGame
	jmp QGInputLoop
			
	
	QGEnd:
	;Go back to text mode
	call clearScreen
	call clearText
	call setTextMode
	
    ;Exit to DOS (end of program)
    mov ax, 4c00h                   ; AH=4Ch - Exit To DOS
    int 21h                         ; DOS INT 21h
ENDP gameOver




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: writeScore
;DESCRIPTION: This procedure writes the score.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC writeScore
	USES eax, ebx, ecx, edx
	
	mov ax, [SCORE]
	mov ecx, 0
	mov ebx, 10
	WSDivideloop:
		mov edx, 0
		div ebx             ;divide the value in eax by the value in ebx, store:
	            			;remainder in edx
	            			;quotient in eax
		push edx            ;push value of edx (remainder) to the stack
		inc ecx             ;increase counter
		cmp eax, 0          ;if cuotient is zero: done
	jnz WSDivideloop

	WSPrintloop:
		pop edx
		add edx, 48         ;convert to ascii
		mov ah, 2           ;DOS function 2: print char to output
		int 21h
		dec ecx             ;while the counter is not zero, continue
	jnz WSPrintloop    
	ret  
ENDP writeScore




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;PROCEDURE: generateCheckboard and generateCage
;DESCRIPTION: The following procedures are small procedures to generate the various 
;playing fields.
;Input:							Registers modified:
;		none							none
;
;Output:
;		none
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
PROC generateCheckboard
	USES eax, ebx, ecx, edx
	
	mov dl, WALLCOLOR
	mov eax, 60
	mov ebx, 52
	mov dh, 0
	
	GOLoop2:
	mov cl, 5
	mov ch, 5
		GOLoop3:
			GOLoop4:
			call drawSquare
			add eax, 4
			dec cl
			jnz GOLoop4
		mov cl, 5
		sub eax, 20
		add ebx, 4
		dec ch
		jnz GOLoop3
		
	cmp dh, 0
	jne GOBlock3
	mov eax, 240
	mov ebx, 52
	inc dh
	jmp GOLoop2
	
	GOBlock3:
	cmp dh, 1
	jne GOBlock4
	mov eax, 60
	mov ebx, 128
	inc dh
	jmp GOLoop2
	
	GOBlock4:
	cmp dh, 2
	jne GOBlock5
	mov eax, 240
	mov ebx, 128
	inc dh
	jmp GOLoop2
	
	GOBlock5:
	cmp dh, 3
	jne GOBlock6
	mov eax, 148
	mov ebx, 52
	inc dh
	jmp GOLoop2
	
	GOBlock6:
	cmp dh, 4
	jne GOEnd
	mov eax, 148
	mov ebx, 128
	inc dh
	jmp GOLoop2
	
	GOEnd:	
	ret
ENDP generateCheckboard


;---------------------------------------------------------------------------------------
PROC generateCage
	USES eax, ebx, ecx, edx
	
	mov dl, WALLCOLOR
	mov eax, 60
	mov ebx, 52
	mov cl, 50
	
	GCLoop1:
		call drawSquare
		add eax, 4
		dec cl
		jnz GCLoop1
		
	mov eax, 60
	mov ebx, 52
	mov cl, 24
	GCLoop2:
		call drawSquare
		add ebx, 4
		dec cl
		jnz GCLoop2
		
	mov eax, 260
	mov ebx, 52
	mov cl, 24
	GCLoop3:
		call drawSquare
		add ebx, 4
		dec cl
		jnz GCLoop3
		
	mov eax, 64
	mov ebx, 144
	mov cl, 22
	mov ch, 2
	GCLoop4:
		call drawSquare
		add eax, 4
		dec cl
		jnz GCLoop4
		add eax, 24
		mov cl, 22
		dec ch
		jnz GCLoop4
	ret	
ENDP generateCage




END start

