; program  odtwarzajacy dzwieki z tablicy, z mozliwoscia przerwanie przez ESCAPE

;Program imitujacy dzwiek syreny
;zmiana czestotliwosci dzwieku od 450 Hz do 2100 Hz
;Opoznienie adekwatne dla procesora P5

format MZ			; format uruchomieniowy programu
stack stk:256		; okreœlenie wartosci offsetu stosu lub jego wielkosci ?
entry text:main 	; okreslenie entry point, miejsca rozpoczecia programu

;makro opoznienia
;Na wejsciu wartosc opoznienia (w mks)

macro delay time
{
local ext,iter
    push cx
    mov cx,time
ext:
    push cx
;w cx jedna mks, te wartosc moÅ¼na zmienic w zaleznosci od wydajnosci procesora
    mov cx,0FFFFh
iter:
    loop iter
    pop cx
    loop ext
    pop cx
}

macro delay2 time2		
{
local spr,iter
    mov [time_08],time2
spr:
	cmp [time_08],0
	je dal
	jmp spr
dal:
}

segment data_16 use16
tonelow  dw	9121, 7240, 6088, 4651, 6088, 7240, 9121	    ;dolna granica dzwieku 450 Hz
cnt	 db	 0					 ;licznik dla wyjscia z programu
temp	 dw	 ?					  ;gorna granica dzwieku
_stare08 dw	 ?			; wektor przerwanai, adres logiczny gdzie znajduje siê procedura obs³ugi przerwania
	 dw	 ?
_stare09 dw	 ?
	 dw	 ?
iteracja dw	 0
mark_08  dw	 0		; ofset okreœlaj¹cy miejsce wyœwietlania
time_08  dw	 0
zmiennaDoDek dw  18
mark_09 dw 320

atryb db 71h
flaga db 0
flaga2	dw  0
klawiszEscpape db 01h
znak dw 45h
segment text use16		; segment programu do ktorego bedzie odwolanie przy zadaniu przerwania
moje08:
		dec [time_08]
		jmp dword [ds:_stare08] 	   ; skaczemy na oryginalne przerwanie


									; iret
									;klawisz escape kod = 1, kod puszczonego klawisz wiêkszy o 128 tutaj 128 czyli 81h
									; sprawdziæ czy jest wciœniêty escape, jeœli tak to ...
									; nutki z pamiêci, po wciœniêciu escape przerwanie grania, jeœli nie gramy dalej
									
									
; test [time_08], 03            ; sprawdza czy jest zero, nie ustawia wartosci tylko znaczniki, tutaj znacznik zera                                                                     
moje09:
	push ax 						; odlozenie na stos rejestrow ktore beda uzywane, np pushall - wszystkie na stos
	push bx
	push es
	xor ax, ax
	in al, 60h						; uzyskanie scankod (wciskany mnijeszy niz 128, puszczany wiekszy o 128) wprowadzonego klawisz
       ; mov [znak],ax
	sub al,[klawiszEscpape]
	jnz dalej
	mov [ds:flaga2] ,1	
dalej:
	in al, 61h		; uzyskanie zawartoœæi portu B, 
	or al, 80h		; ustawienie bardziej znacz¹cego bitu wartoscia 1
	out 61h,al		; a nastepnie reset, wyslanie do portu 61h
	and al,7Fh		; poinformuj kontroler o zakonczeniu przerwaniu (obsluzeniu)
	out 61h,al		;uzyskanie skan kodu symbolu

	mov al,20h		;rozkaz EOI konca przerwania, do portu 20h wysylamy kod 20h, informacja dla kontrolera o zakonczeniu przerwania
	out 20h,al

	pop es
	pop bx
	pop ax							; 

	iret							; interupt return - sciaga dodatkowo flagi ze stosu (rejestr flag)
	
					; port 43h, programowanie kanalu 1, po przeslaniu 0B6h czyli 10110110 do mov al, 0B6h, out 43h, al - uruchomimy kanal drugi

main:
	mov	ax,data_16		;; do rejestru ds wpisujemy inf o segmencie data_16, wskazuje na ofset data_16
	mov	ds,ax			; to samo tylko osegment stosu
;        mov     ax, stk
;        mov     ss, ax
;        mov     sp, 256                ; ustawienie wskaznika stosu na 256
;;        xor     ax,ax

;    if iteracja>0
;        mov cx,iteracja
;        rep movsb
;    end if
 start01:
	;push ax
       ; push es
	;push bx
							  ; funkcja nasposujaca oryginalne przerwanie, przerwanie pod adresem 32 (poniewaz 4 x 8)
	cli						  ; blokada obbs³ugi przerwañ, clear interupt, ustawia odpowiedni bit
	xor ax,ax					  ; zerowanie ax
	mov es, ax					  ; ladowanie do rejestru segmentowego es, zerowane jest,a bydostac sie na dol pamieci,
	les bx, [es: (8 shl 2)] 			  ; odczytanie 4 bitow, ósmy wektor przerwania, przerwania .., shl - przesuniecie bitowe czyli x2, robione 8 razy daje adres 32
							  ; odczytanie 4 bajtow, dwa bajty wrzuca do es(segment), pozostale do bx(offset)
	mov [_stare08+2],es						; zapisnie starego przerwania pod adresem _stare_08
	mov [_stare08], bx						; zapisanie pod adresem pod wskzanym adresem adres starego przerwania
	mov es, ax								; znowu zerujemy es
	mov word [es: (8 shl 2)], moje08		; pokazanie gdzie jest nowe przerwanie ttaj segment
	mov word [es: (8 shl 2)+2],text 		; tutaj offset, wskazanie adresu gdzie jest nowe przerwanie
											; odblokowanie obs³ugi przerwañ
       ; pop bx
	;pop es
       ; pop ax
       ; xor ax, ax
	mov es, ax
	les bx, [es: (9 shl 2)] 	       ; ósmy wektor przerwania, przerwania ..
	mov [_stare09+2],es			; zapisnie starego przerwania pod adresem _stare_08
	mov [_stare09], bx
	mov es, ax
	mov word [es: (9 shl 2)], moje09
	mov word [es: (9 shl 2)+2],text
	sti							; odblokowanie obslugi przerwan

go:
; czesc programu odpowiedzialna za odtwarzanie dzwieku
	mov	al,0B6h 				; slowo stanu 10110110b (0B6h)-wybor 2-ego kanalu portu (glosnik)
	out	43h,al					;do portu 43h
	in	al,61h		
	or	al,3		
	out	61h,al
	mov bx, tonelow

	mov	cx,7
	petlaWew:
		  push cx
		  push bx			 ; reset i zapamietanie wczeœniejszych informacji na rejestrach
		  push ax
		  push dx
		  xor	bx, bx
		  xor dx, dx
		  mov dx, [iteracja]		  ;przeniesienie wartosci iteracji do rejestru
		  add bx, [tonelow+edx] 	  ; dodajemy do adresu tablicy iteracje, kolejna wartosc z tabeli [edx to wieksza czesc dl ]
		  mov [temp], bx		    ; przenosimy nowa wartosc do temp
		  ; mov dx,9121
		  ; mov [temp],dx
		  mov	  cx,4
		  music:
			mov	ax,[temp]
			out	42h,al
			mov	al,ah
			out	42h,al
			delay2 2		; czas miêdzy tonami, jako zmienna przekazana do funkcji delay

			 mov ah,2
			 mov dx,[znak]
			 int 21h

		       cmp [flaga2], 1	       ; sprawdz czy w flaga jest 1 - tzn poszukiwany klawisz(tutaj escape)
		       je nosound
		  loop	  music
		  inc [iteracja]
		  inc [iteracja]
		  pop dx
		  pop ax
		  pop bx
		  pop cx
	loop petlaWew
; koniec czesci odpowiedzialnej za dzwiek



nosound:
	in	al,61h		; resetowanie dwoch najmlodszych bitow na porcie 61h, wtedy wylaczamy dzwiek, aby wlaczyc wpisujemy 3 do portu 61h
	and	al,0fch 	; 11111100 wtedy zerujemy dwa najmlodsze bity
	out	61h,al		;
start02:
	cli
	xor ax,ax					    ; segment - tutaj zerowy, przywrócenie starego przerwania
	les cx, dword [ds: _stare08]	; offest
	mov ds, ax
	mov [ds: (8 shl 2)],cx			; zaladowanie adresu
	mov [ds: (8 shl 2) + 2], es

	mov ax, data_16
	mov ds, ax
	les cx, dword [ds: _stare09]
	xor ax,ax
	mov ds, ax
	mov [ds: (9 shl 2)],cx			; offest gdzie zapisany jest offset
	mov [ds: (9 shl 2) + 2], es		; segment

	mov ax, data_16
	mov ds, ax
	sti

;        mov     dx,51                                   ;dla kolejnych petli
;        mov     [tonelow],dx
;        inc     byte  [cnt]                             ;inkrementacja ilosci przejsc
;        cmp     byte  [cnt],1
;        jne     go
exit:
	mov	ax,4c00h					; oczekiwanie na wcisniecie klawisz, zamkniecie programu
	int	21h
	ret
segment stk use16
    db 256 dup (?)
