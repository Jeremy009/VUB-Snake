;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Jeremy Lombaerts
;MA Physics and Asronomy
;Computersystemen: Project - Snake
;File: HELPERS.ASM
;
;DESCRIPTION: The following procedures are small helper procedures. Their goal and 
;should be trivial to understand.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------




IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "HELPERS.INC"




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Begin data segment.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
DATASEG
	VIDEOORIGIN		equ 0a0000h		;The first address of the video memory
	




;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
;Begin code segment. This is where the actual code is located.
;---------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------
CODESEG
PROC setVideoMode
	USES eax
	
	mov eax, 13h
	int 10h
	
	ret
ENDP setVideoMode


;---------------------------------------------------------------------------------------
PROC setTextMode
	USES eax

	mov	ax, 03h
	int	10h

	ret
ENDP setTextMode


;---------------------------------------------------------------------------------------
PROC clearScreen
	USES eax, ecx, edi
	
	mov edi, VIDEOORIGIN			;Begin of memory(stack) secion reserved f/ vid memory
	mov ecx, 64000/4				;Use of stosd(ouble word) writes 4 bytes at once
	mov eax, 00000000h				;Code for 4 black pixels.
	rep stosd						;For ecx repetitions, stores eax into [edi], and 
	ret								;increase edi by 4						
ENDP clearScreen


;---------------------------------------------------------------------------------------
PROC clearText
	USES eax, ebx, edx
	
	xor   dx,dx        	;Use the set cursor position function to clear the screen,
	xor   bh,bh        	;by setting it to the first column, row and page.
	mov   ah,2h			;dh,dl contain row and column
	int   10h			;Setting bh to 0 = page 1
	ret
ENDP clearText


;---------------------------------------------------------------------------------------
;PROCEDURE setNewLines sets ecx newLines. ecx must contain the correct value before call
PROC setNewLines
	USES eax, ecx, edx
	
	;Display some newlines
	mov dl, 10						;ASCII-code 10: Line feed, newline
	mov ah, 02h						;INT21H, function 02h = Write char to std output
	SNLLoop:
		int 21h						;Call DOS functionality
		dec ecx
	jnz SNLLoop	
	ret	
ENDP setNewLines

END
