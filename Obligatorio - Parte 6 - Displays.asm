; PIC16F887 Configuration Bit Settings
; Assembly source line config statements
;#include "delay-10ms.inc"
#include "p16f887.inc"
    
; Bits de configuracion

; CONFIG1
; __config 0xE0C2
 __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0xFEFF
 __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

; Organizacion de la memoria EEPROM.
; 0x30 -> Flag que indica si est� usado el buffer o no.
; 0x31 -> Puntero actual del buffer.
; 0x40 - 0x49 -> Buffer.
    
; Organizacion de la memoria de datos 
cblock 0x20	; Comienzo a escribir la memoria de datos en la direccion 0x20
; Definicion de variables
    ASCII_CONVERSION
    ASCII_TEMP
    ASCII1
    ASCII2
    ASCII3
    COCIENTE
    CONTADOR_
    CONTADOR_1
    CONTADOR_2
    CONTADOR_TIMER1
    DELAY_1MS_CONTADOR_1
    DELAY_1MS_CONTADOR_2
    DELAY_CONTADOR
    DIVIDENDO
    DIVISOR_REGLA
    ITERADOR
    MULT
    MULTIPLICANDO
    MULTIPLICANDO_REGLA
    PRODH
    PRODL
    PUNTERO_ACTUAL
    REGLAE
    REGLAF
    RESTO
    SIGUIENTE_PUNTERO
    STATUS_TEMP
    STATUS_TEMP_CASE
    TEMP_W
    VALOR_CONVERSION
    VALOR_CONVERSION_MEMORIA
    VALOR_CONVERSION_REGLA
    VALOR_CONVERSION_TEMP
    VALOR_CONVERSIONH
    VALOR_CONVERSIONL
    W_TEMP
    W_TEMP_CASE
    CONTADOR_MEDIDAS
    DISPLAY_TEMP1
    DISPLAY_TEMP2

endc
   
;Organizacion de la memoria de programacion
org 0x0000
goto main

org 0x0004
goto interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
main
    call configuracion_inicial
    
mainloop
    call realizar_conversion
    ; NOTA: PARA REALIZAR SIN INTERRUPCIONES, DESCOMENTAR ESTO:
;    call leer_usart
    
    ;check buttons
    call rb_wait_press
    
    goto mainloop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINA DE INTERRUPCION ;;;;;;;;;;;;;;;;;;;;;;;;;;

interrupt
    call guardar_contexto

    ; Identifico la interrupcion.
    banksel PIR1
    btfss PIR1, TMR1IF ; Interrupcion timer1?
    goto $+3
    bcf PIR1, TMR1IF
    call interrupt_tmr1    

    ; NOTA: PARA SACAR LAS INTERRUPCIONES DE USART, COMENTAR ESTO:
    banksel PIR1
    btfss PIR1, RCIF ; Interrupcion usart?
    goto $+3
    bcf PIR1, RCIF
    call interrupt_usart
    
    banksel PIR2
    btfss PIR2, EEIF; Interrupcion escritura?
    goto $+3
    bcf PIR2, EEIF
    call interrupt_eeprom    

    call cargar_contexto
    retfie ; interrupt
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CONFIGURACION INICIAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;

configuracion_inicial	
    ; Configuro las entradas de voltaje analogicas (PUERTOA).
    banksel TRISA
    bsf TRISA, 0 ; Seteo RA0 como entrada (perilla analogica)
    bsf TRISA, 1 ; Seteo RA1 como entrada (perilla anal�gica)
    banksel ANSEL
    bsf ANSEL, 0 ; Seto el puerto RA0 como analogico.
    bsf ANSEL, 1 ; Seto el puerto RA1 como analogico.

    ; Configuracion de la conversi�n anal�gica.
    banksel ADRESH
    clrf ADRESH
    banksel ADRESL
    clrf ADRESL
    banksel ADCON1
    clrf ADCON1 ; ADFM = Left justified | VCFG1 = Vss | VCFG0 = Vdd	
    ; Configuraci�n del reloj y encendido del conversor analogico.
    banksel ADCON0 
    movlw b'10000001'
    movwf ADCON0 ; ADCS = Fosc/32 (TAD: 1.6(x10^-6)s) | ADON = ADC is enabled.

    ; Configuro las interrupciones.
    bsf INTCON, GIE ; Global interrupt enable bit.
    bsf INTCON, PEIE ; Pheripheral interrupt enable bit.
	
    ; Configuracion puerto serie (EUSART)
    ; Configuracion baudrate
    banksel TXSTA
    bsf TXSTA, BRGH ; BRGH = High Speed
    banksel BAUDCTL
    bcf BAUDCTL, BRG16 ; BRG16 = 8-bit Baud Rate Generator is used.
    banksel SPBRGH
    clrf SPBRGH
    banksel SPBRG
    movlw d'129' 	
    movwf SPBRG ; Baudrate 9600
    ; Configuro la transmision.
    banksel TXSTA
    bsf TXSTA, TXEN  ; Transmit Enable bit = Transmit enabled
    bcf TXSTA, SYNC  ; EUSART mode select bit = Asynchronous mode
    ; Configuro la recepcion.
    banksel RCSTA
    bsf RCSTA, CREN  ; Continuous Recive Enable bit = Enables receiver
    bsf RCSTA, SPEN  ; Serial Port Enable bit = Serial port enabled.
    ; NOTA: PARA SACAR LAS INTERRUCIONES, COMENTAR ESTO:
    banksel PIE1 
    bsf PIE1, RCIE ; Configuro que se generen interrupciones con la recepci�n

     ; Chequeo inicial de la memoria EEPROM.
    movlw 0x30
    call leer_memoria
    ; Chequeo que en la direcci�n 0x30 exista el valor 0x77. Si existe este 
    ; valor significa que la memoria est� inicializada, sino hay que
    ; inicializarla.
    sublw 0x77
    ; INICIO IF
	btfsc STATUS, Z
	; THEN (w = 0x77)
	goto $+2
	; ELSE (w <> 0x77)
	call inicializar_eeprom
    ; FIN IF   
    
     ; Configuro el timer1.
    banksel PIE1 ;  Timer1 Overflow Interrupt Enable bit
    bsf PIE1, TMR1IE    
    banksel PIR1
    bcf PIR1, TMR1IF ; Timer1 Overflow Interrupt Flag bit
    banksel T1CON
    bcf T1CON, TMR1CS ; Timer1 Clock Source Select bit = Clock
    ; Configurar preescaler timer1(1:8)
    bsf T1CON, T1CKPS0
    bsf T1CON, T1CKPS1
    bsf T1CON, TMR1ON ; Encender el timer.
    ; Reinicio el contador tmr1.
    call re_iniciar_contador1
    ; Reinicio el timer1.
    call re_iniciar_timer1
	
    ; Configurar para display
    call configurar_botones
    call conf_7seg
    
    return ; configurar_puertos

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RUTINAS PROGRAMA PRINCIPAL ;;;;;;;;;;;;;;;;;;;;;;

leer_usart
    banksel PIR1
    btfss PIR1, RCIF ; Interrupcion usart?
    goto $+3
    call interrupt_usart
    bcf PIR1, RCIF
    
    return ; leer_usart
    
; Lee el contenido del puerto y dervia en un case que indica que letra se
; ingres�.
interrupt_usart
    banksel RCREG
    movf RCREG, w
    
    ; Case letras:
    xorlw b'01000001' ; 0x41 = 'A' (ASCII)
    btfsc STATUS, Z
    call rutina_letra_A
 
    xorlw b'01001000' ^ b'01000001' ; 0x48 = 'H' (ASCII)
    btfsc STATUS, Z               
    call rutina_letra_H
    
    xorlw b'01100001' ^ b'01001000' ; 0x61 = 'a' (ASCII)
    btfsc STATUS, Z               
    call rutina_letra_a
    
    return ; interrupt_usart

; Rutina de letra A: Obtiene el valor actual de la conversion y la env�a por
; el puerto usart.
rutina_letra_A
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call enviar_conversion_usart_hexa

    return ; rutina_letra_A
    
; Rutina de letra H: Obtiene los valores de memoria del buffer circular y los
; env�a por el puerto usart.
rutina_letra_H    
    ; Leo el puntero del buffer actual.
    movlw 0x31
    call leer_memoria
    
    ; Guardo el valor del puntero actual.
    banksel PUNTERO_ACTUAL
    movwf PUNTERO_ACTUAL
    
    ; Guardo el valor inicial de ITERADOR.
    banksel ITERADOR
    movwf ITERADOR

    WhileLoopInicio
	; Obtengo el dato que apunta ITERADOR.
	banksel ITERADOR
	movf ITERADOR, w
	banksel EEADR
	movwf EEADR
	call leer_memoria
	
	; Env�o el dato (contenido en w) por el puerto usart.
	call enviar_conversion_usart_hexa
	; Env�o un salto de linea.
	movlw d'10'
	call enviar_w
	
	; Incremento ITERADOR.
	banksel ITERADOR
	decf ITERADOR, f
	; Chequeo que no me pase el buffer.
	movf ITERADOR, w
	sublw 0x3F
	; INICIO IF
	    btfss STATUS, C	    
	    ; THEN (w > 0x3F)
	    goto $+3
	    ; ELSE (w <= 0x3F)
	    movlw 0x49
	    movwf ITERADOR
	; FIN IF
	
	; Compruebo que no llegue al PUNTERO_ACTUAL (fin del loop)	
	banksel PUNTERO_ACTUAL
	movf PUNTERO_ACTUAL, w
	banksel ITERADOR
	subwf ITERADOR, w
	; INICIO IF
	    btfsc STATUS, Z
	    ; THEN (ITERADOR = PUNTERO_ACTUAL)
	    goto $+2 
	    ; ELSE (ITERADOR <> PUNTERO_ACTUAL)
	    goto WhileLoopInicio
	; FIN IF
	
    return ; rutina_letra_H
    
; Manda la conversion en formato decimal.
rutina_letra_a    
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call enviar_conversion_usart_dec
    
     ; Env�o grados centr�grados.
    movlw d'186' ; �
    call enviar_w
    movlw d'67' ; C
    call enviar_w
    
    return ; rutina_letra_a

; Obtiene el valor de la conversion en w, lo mapea a decimal y lo env�a por el
; puerto usart.
enviar_conversion_usart_dec
    banksel VALOR_CONVERSION_TEMP
    movwf VALOR_CONVERSION_TEMP
    
    banksel MULTIPLICANDO_REGLA
    movlw d'100'
    movwf MULTIPLICANDO_REGLA
    
    banksel DIVISOR_REGLA
    movlw d'255'
    movwf DIVISOR_REGLA
 
    banksel VALOR_CONVERSION_TEMP
    movf VALOR_CONVERSION_TEMP, w
    
    call regla_de_tres
    
    banksel REGLAE
    movf REGLAE, w
    call mapear_enviar_dec
    
    return ; enviar_conversion_usart_dec
    
; Realiza una regla de tres.
; w = w*MULTIPLICANDO_REGLA/DIVISOR_REGLA
regla_de_tres
    banksel VALOR_CONVERSION_REGLA
    movwf VALOR_CONVERSION_REGLA
    movf MULTIPLICANDO_REGLA, w
    movwf MULTIPLICANDO
    movf VALOR_CONVERSION_REGLA, w
    call multiplicar
    
    ; Si la multiplicaci�n dio 0, devuelvo 0.
    banksel PRODH
    movf PRODH, f
    ; INICIO IF
	btfss STATUS, Z
	; THEN (PRODH <> 0)
	goto $+7
	; ELSE (PRODH = 0)
	banksel PRODL
	movf PRODL, f
	; INICIO IF
	    btfss STATUS, Z
	    ; THEN (PRODL <> 0)
	    goto $+2
	    ; ELSE (PRODL = 0)
	    retlw 0 ; Si es 0 el producto, devuelvo 0 porque no puedo dividir.
	; FIN IF
    ; FIN IF
    
    ; LOS PARAMETROS DE dividir YA ESTAN CARGADOS, CARGO SOLO w.
    banksel DIVISOR_REGLA
    movf DIVISOR_REGLA, w
    call dividir
    
    banksel COCIENTE
    movf COCIENTE, w
    movwf REGLAE
    movf RESTO, w
    movwf REGLAF    
    
    return ; regla_de_tres

; Multiplica dos numeros.
; MULTIPLICANDO * w = PRODH:PRODL
multiplicar
    banksel MULT
    movwf MULT
    
    ; Limpio los resultados.
    banksel PRODL
    clrf PRODL
    clrf PRODH
    
    banksel MULTIPLICANDO
    movf MULTIPLICANDO, f
    ; INICIO IF
	btfsc STATUS, Z
	; THEN (MULTIPLICANDO = 0)
	return
	; ELSE (MULTIPLICANDO <> 0)
	multiplicar_loop
	    banksel MULT
	    movf MULT, w
	    banksel PRODL
	    addwf PRODL, f
	    btfsc STATUS, C
	    incf PRODH, f
	    decfsz MULTIPLICANDO, f
	    goto multiplicar_loop	    
    ; FIN IF
    return ; multiplicar

; Divide dos numeros.
; PRODH:PRODL/w = w*COCIENTE + RESTO
dividir
    banksel COCIENTE
    clrf COCIENTE
    clrf RESTO
    movwf DIVIDENDO
    
    loop_dividir
	banksel PRODH
	movf PRODH, f
	; INICIO IF
	    btfss STATUS, Z
	    ; THEN (PRODH <> 0)
	    goto restar_dividir
	    ; ELSE (PRODH = 0)
	    movf DIVIDENDO, w
	    subwf PRODL, w
	    ; INICIO IF
		btfsc STATUS, C
		; THEN (PRODL >= DIVIDENDO)
		goto restar_dividir
		; ELSE (PRODL < DIVIDENDO)
		movf PRODL, w
		movwf RESTO
		return ; dividir
	    ; FIN IF
	; FIN IF
	
	restar_dividir
	    banksel COCIENTE
	    incf COCIENTE, f
	    
	    movf DIVIDENDO, w
	    subwf PRODL, f
	    ; INICIO IF
		btfsc STATUS, C
		; THEN (PRODL < DIVIDENDO)
		goto $+2
		; ELSE (PRODL >= DIVIDENDO)
		decf PRODH, f
	    goto loop_dividir

; Mapea y env�a un valor decimal por el puerto usart.
mapear_enviar_dec
    call convertir_valor_dec
    banksel ASCII_TEMP
    movwf ASCII_TEMP
    movf ASCII_CONVERSION, w
    movwf ASCII3 ; Almaceno el resultado
    
    movf ASCII_TEMP, w
    call convertir_valor_dec
    banksel ASCII_TEMP
    movwf ASCII_TEMP
    movf ASCII_CONVERSION, w
    movwf ASCII2 ; Almaceno el resultado
    
    movf ASCII_TEMP, w
    call convertir_valor_dec
    banksel ASCII_TEMP
    movwf ASCII_TEMP
    movf ASCII_CONVERSION, w
    movwf ASCII1 ; Almaceno el resultado
    
    banksel ASCII1
    movf ASCII1, w
    call enviar_w
    
    banksel ASCII2
    movf ASCII2, w
    call enviar_w
    
    banksel ASCII3
    movf ASCII3, w
    call enviar_w   
    
    return ; mapear_enviar_dec
    
; Convierte solo una parte del valor en w.
; ASCII_CONVERSION = w MOD DIVISOR
; w = w/DIVISOR
convertir_valor_dec
    banksel PRODL
    movwf PRODL
    movlw d'10'
    call dividir
    
    banksel RESTO
    movf RESTO, w    
    addlw b'00110000' ; Sumo 30.
    movwf ASCII_CONVERSION ; Almaceno el resultado
    
    banksel COCIENTE
    movf COCIENTE, w
    
    return ; convertir_valor_dec
    
; Obtiene el valor de la conversi�n en w, lo mapea y lo env�a por el puerto
; usart.
enviar_conversion_usart_hexa	
    banksel VALOR_CONVERSION_TEMP
    movwf VALOR_CONVERSION_TEMP

    ; Obtengo los valores High y Low de la conversion.
    andlw b'11110000'
    banksel VALOR_CONVERSIONH
    movwf VALOR_CONVERSIONH
    swapf VALOR_CONVERSIONH, f 	; Hago swamp para cambiar de lugar y 
				; tener todos en los bits menos significativos.
    
    banksel VALOR_CONVERSION_TEMP
    movf VALOR_CONVERSION_TEMP, w
    andlw b'00001111'
    banksel VALOR_CONVERSIONL
    movwf VALOR_CONVERSIONL
    
    banksel VALOR_CONVERSIONH
    movf VALOR_CONVERSIONH, w
    call mapear_enviar_hexa
    
    ; Mapeo y env�o los valores por el puerto usart.
    banksel VALOR_CONVERSIONL
    movf VALOR_CONVERSIONL, w
    call mapear_enviar_hexa    
    
    return ; enviar_conversion_usart_hexa
	
; Mapea el valor de w a un caracter ASCII y lo env�a por el puerto USART.
mapear_enviar_hexa 
    call mapear_hexa
    call enviar_w
    return ; mapear_enviar_hexa
	
; Envia el valor del registro w por el puerto USART.
enviar_w
    banksel PIR1
    btfss PIR1, TXIF ; Esta vac�o el bus de transmisi�n?
    goto $-1 ; No, vuelvo a chequear hasta que est� libre.
    banksel TXREG
    movwf TXREG 
    return ; enviar_w
	
; Mapea el valor de w a un caracter ASCII y lo guarda en w.
mapear_hexa
    banksel TEMP_W
    movwf TEMP_W
    sublw b'00001001' ; 0x09 -> 9 decimal
    ; INICIO IF
	btfss STATUS, C
	; THEN (w > 9)
	goto sumar_37 ; Es mayor a 9, entonces sumo 0x37 = 0011 0111
	; ELSE (w <= 9)
	goto sumar_30 ; Es menor o igual 9, entonces sumo 0x30 = 0011 0000
    ; FIN IF

; Sumo 30h al valor que tengo en w.
sumar_30
    banksel TEMP_W
    movf TEMP_W, w
    addlw b'00110000' ; 0x30 -> 48 decimal
    return ; mapear_hexa

; Sumo 37h al valor que tengo en w.
sumar_37
    banksel TEMP_W
    movf TEMP_W, w
    addlw b'00110111' ; 0x37 -> 55 decimal
    return ; mapear_hexa
	
; Inicializa la memoria EEPROM.
inicializar_eeprom
    ; Inicializo la flag de memoria inicializada.
    ; Cargo 0x30 (Puntero flag del buffer)
    movlw 0x30
    banksel EEADR
    movwf EEADR
    ; Cargo el dato que indica que est� inicializada la memoria.
    movlw 0x77
    banksel EEDAT
    movwf EEDAT
    ; Guardo el valor de w en memoria.
    call guardar_memoria

    ; Inicializo el puntero inicial del donde arranca el buffer.
    ; Cargo 0x31 (SIGUIENTE_PUNTERO)
    movlw 0x31
    banksel EEADR
    movwf EEADR
    ; Cargo el dato que indica que est� inicializada la memoria.
    movlw 0x49
    banksel EEDAT
    movwf EEDAT
    ; Guardo el valor de w en memoria.
    call guardar_memoria

    return ; inicializar_eeprom

; Guarda el valor de VALOR_CONVERSION en el buffer circular.
guardar_memoria_VALOR_CONVERSION
    ; Cargo SIGUIENTE_PUNTERO e impacto en memoria.
    call obtener_siguiente_puntero
    ; Cargo el dato de VALOR_CONVERSION en EEDAT.
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    banksel EEDAT
    movwf EEDAT
    ; Cargo el puntero de SIGUIENTE_PUNTERO en EEADR.
    banksel SIGUIENTE_PUNTERO
    movf SIGUIENTE_PUNTERO, w
    banksel EEADR
    movwf EEADR
    ; Guardo el valor de w en memoria.
    call guardar_memoria
    call contar_medida
    return ; guardar_memoria_VALOR_CONVERSION

; Obtiene y guarda el siguiente puntero del buffer en memoria.	
obtener_siguiente_puntero
    ; Cargo 0X31 (Puntero de SIGUIENTE_PUNTERO) en EEADR
    movlw 0x31
    banksel EEADR
    movwf EEADR
    ; Cargo el valor de memoria en w.
    call leer_memoria

    ; Sumo 1 al puntero.
    addlw d'1'
    banksel SIGUIENTE_PUNTERO
    movwf SIGUIENTE_PUNTERO

    ; Chequeo que no me pase del buffer.
    sublw 0x49
    ; INICIO IF
	btfsc STATUS, C
	; THEN (w <= 0x49)
	goto $+3
	; ELSE (w > 0x49)
	movlw 0x40
	movwf SIGUIENTE_PUNTERO
    ; FIN IF

    ; Cargo el dato de SIGUIENTE_PUNTERO en EEDAT.
    movf SIGUIENTE_PUNTERO, w
    banksel EEDAT
    movwf EEDAT
    ; Cargo el puntero de SIGUIENTE_PUNTERO en EEADR.
    movlw 0x31
    banksel EEADR
    movwf EEADR
    ; Guardo el valor de w en memoria.
    call guardar_memoria	

    return ; obtener_siguiente_puntero

; Leo un valor ya seteado en EEADR de memoria en w.
leer_memoria
    banksel EEADR
    movwf EEADR ; Cargo la direcci�n.

    banksel EECON1
    bcf EECON1, EEPGD ; Apunto a la EEPROM
    bsf EECON1, RD ; Activo la lectura.
    banksel EEDAT
    movf EEDAT, w ; Guardo el valor en w.

    return ; leer_memoria

guardar_memoria
    banksel EECON1
    bcf EECON1, EEPGD ; Apunto a la EEPROM
    bsf EECON1, WREN ; Activo la escritura.

    bcf INTCON, GIE ; Desactivo interrupciones.
    btfsc INTCON, GIE
    goto $-2

    ; SECCION INTOCABLE
    movlw 0x55
    movwf EECON2
    movlw 0xAA
    movwf EECON2
    bsf EECON1, WR ; Se comienza la escritura.
    ; FIN SECCION INTOCABLE

    bsf INTCON, GIE ; Activo las interrupciones.
    btfsc EECON1, WR
    goto $-1
    bcf EECON1, WREN
    return ; guardar_memoria
	
; Configurar CONTADOR_TIMER1
re_iniciar_contador1
    banksel CONTADOR_TIMER1
    movlw d'100'
    movwf CONTADOR_TIMER1

    return ; re_iniciar_contador1

; Rutina de interrupci�n del tmr1.
interrupt_tmr1
    ; Decremento el contador.
    banksel CONTADOR_TIMER1
    ; INICIO IF
	    decfsz CONTADOR_TIMER1, f
	    ; CONTADOR_TIMER <> 0 THEN
	    goto $+3
	    ; ELSE
	    call guardar_memoria_VALOR_CONVERSION
	    call re_iniciar_contador1
    ; FIN IF
    call re_iniciar_timer1

    return ; interrupt_tmr1

; Interrupcion de escritura de la eepron.
interrupt_eeprom
    banksel PIR2
    bcf PIR2, EEIF ; Limpio la interrupcion de la eeprom

    return ; interrupt_eeprom

; Inicia el timer con el valor precargado, para una interrupci�n cada 100 ms.
re_iniciar_timer1
;;;;;;;;;;;; Calculo para la cantidad de tiempo ;;;;;;;;;;;;;;;;
    ; ValorTimer = ValorMaximoTimer - ((DelaySolicitado * Fosc) / (Prescalar * 4))
    ; Formula para 100 ms: ValorTimer = 65536 - ((100ms * 20Mhz) / (8 * 4)) = 3036

    ; Cargar 3036 (00001011 11011100)
    banksel PIR1
    
    movlw b'11011100' 
    movwf  TMR1L
    movlw b'00001011' 
    movwf  TMR1H
    
    bcf PIR1, TMR1IF ; Timer1 Overflow Interrupt Flag bit
    return ; re_iniciar_timer1

; Realiza la conversion y almacena los valores en variables.
realizar_conversion
    bsf ADCON0, GO ; Start conversion
    btfsc ADCON0, GO ; Is conversion done?
    goto $-1 ; No, test again
	
    ; Obtener el valor de la conversi�n.
    banksel ADRESH
    movf ADRESH, w
    banksel VALOR_CONVERSION
    movwf VALOR_CONVERSION
	
    return ; realizar_conversion

; Rutinas de contexto.
guardar_contexto
    banksel W_TEMP
    movwf W_TEMP  ; Guardo w.
    swapf STATUS, w ; Swap status en w.
    movwf STATUS_TEMP ; Guardo STATUS.
    return ; guardar_contexto
    
cargar_contexto
    banksel STATUS_TEMP
    swapf STATUS_TEMP, w
    movwf STATUS
    swapf W_TEMP, f
    swapf W_TEMP, w
    return ; cargar_contexto
	
	
;Otros
contar_medida
    banksel CONTADOR_MEDIDAS
    incf CONTADOR_MEDIDAS, d'1'
    return
	
;1) Total de medidas registradas desde el inicio.
display_total_de_medidas
    banksel CONTADOR_MEDIDAS
    movf CONTADOR_MEDIDAS, w
    call show_in_display_0
    return

;2) Cantidad de medidas guardadas (hasta 10)
display_medidas_guardadas
    banksel CONTADOR_MEDIDAS
    movf CONTADOR_MEDIDAS, w
    sublw d'10'
    btfsc STATUS, C
    movlw d'10'
    call show_in_display_0
    return

;3) Valor actual de la temperatura.
display_temperatura_actual
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call show_in_display_0
    return

;4) Tiempo restante hasta registrar la pr�xima medida.
display_tiempo_restante
    banksel CONTADOR_TIMER1
    movf CONTADOR_TIMER1, w
    sublw d'10'
    call show_in_display_0
    return

;5) Valor de la �ltima medida guardada.
display_ultima_medida
    banksel VALOR_CONVERSION
    movf VALOR_CONVERSION, w
    call show_in_display_0
    return

    ; shows w value in the display.
show_in_display
    call map_val_7seg  ; get correct pins that need to be set
    banksel PORTA
    movlw b'11000011'
    andwf PORTA        ; clear only display pins in the port
    banksel DISPLAY_TEMP1
    movf DISPLAY_TEMP1, w
    banksel PORTA
    iorwf PORTA	       ; set only display pins in the port
    return

        ; shows value only in display 0.
show_in_display_0
    banksel PORTE
    bcf PORTE, RE1	    ; turn off both displays
    bcf PORTE, RE2	    ; turn off both displays
    call show_in_display    ; set display pins to value
    bsf PORTE, RE2          ; turn on display 0
    return
    
    
    ; maps 4-bit value in w to match 7 segment display layout.
map_val_7seg
    banksel DISPLAY_TEMP1
    movwf DISPLAY_TEMP1
    clrf DISPLAY_TEMP2
    
    btfsc DISPLAY_TEMP1, 0  ; D0 maps to RA2
    bsf DISPLAY_TEMP2, 2
    btfsc DISPLAY_TEMP1, 1  ; D1 maps to RA1
    bsf DISPLAY_TEMP2, 5
    btfsc DISPLAY_TEMP1, 2  ; D2 maps to RA4
    bsf DISPLAY_TEMP2, 4
    btfsc DISPLAY_TEMP1, 3  ; D3 maps to RA3
    bsf DISPLAY_TEMP2, 3
    movf DISPLAY_TEMP2, w
    return

configurar_botones
    banksel ANSELH
    clrf ANSELH	   ; PORTB is digital
    banksel TRISB
    movlw b'00111111'  ; all inputs but debug pins
    movwf TRISB
    return
    
conf_7seg
    banksel TRISA
	  ; 76543210
    movlw b'11000011'  ; only clears 7 segment display pins as output
    andwf TRISA
    movlw b'11111000'  ; only clears display select/dot as output
    andwf TRISE
    return
	    
rb_wait_press
    banksel PORTB
    btfss PORTB, RB0
    ;goto $-1
    call display_total_de_medidas
    
    btfss PORTB, RB1
    call display_medidas_guardadas
    	
    btfss PORTB, RB2
    call display_temperatura_actual
    
    btfss PORTB, RB3
    call display_tiempo_restante
    
    btfss PORTB, RB4
    call display_ultima_medida
    
    return 

    
end