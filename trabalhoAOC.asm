.model small                            ;define o modelo de memoria do programa
.stack 100h                                 ;reserva espaco de memoria na pilha
.data                    ;define a area de declaracao de variaveis e constantes

;------------------------STRINGS,BUFFER E CONSTANTES---------------------------
;
;-------------------------------CONSTANTES-------------------------------------
BACK      EQU     8                                                  ;BACKSPACE
SPACE     EQU    32                                                      ;SPACE
COMMA     EQU    44                                                    ;virgula
DOT       EQU    46                                                      ;ponto
ESC_KEY   EQU    27                                                        ;ESC
RET_KEY   EQU    13                                                      ;ENTER
TAB_KEY   EQU    09                                                        ;TAB

BEEP_BOOP EQU    07                                                       ;BEEP
o_letter  EQU    111                                       ;letra 'o' minuscula
ordinal_o EQU    167                       ;caractere para numeros ordinais 'º'
capital   EQU    32           ;diferenca entre maiusculas e minusculas na ascii
;
;-------------------------STRINGS DE MENSAGEM AO USUARIO-----------------------
;mensagens para o usuario                                                                    
msg       db 13,10,'Digite uma string contendo ate 35 caracteres: ' ,13,10,'$'
msg2      db 13,10,'Conteudo do buffer... :',13,10,'$'
new_line  db 13,10,'$'
;
;-------------------------BUFFER DE LEITURA PARA INT 21H AH=1h-----------------
;buffer para armezenar a a string do teclado
buff      db 36 dup('$')           ;armazena a string de ate 35 caracteres + \n
;------------------------------------------------------------------------------
;
.code                                              ;define o inicio do programa

;Set cursor position    AH=02h  BH = Page Number, DH = Row, DL = Column
;entrada dl=x (colunas) dh=y(linhas) -> seta o cursor
set_cursor proc 
    mov ah, 2
    mov bh, 0
    int 10h
    ret
set_cursor endp

;entrada DL = caractere a ser printado
print_c proc
    mov ah, 2
    int 21h
    ret
print_c endp

;grava no buffer e printa na tela
;dl = entrada
record_buffer proc
    mov buff[di], dl          ;realiza a copia do caractere para string
                                      ;e o printa na tela
    mov ah, 2
    int 21h
            
    inc di                                         ;incrementa o indice
    inc cx                                         ;inccrementa cursor
    ret
record_buffer endp

backspace proc
    mov ah, 06h
    mov dl,' '
    int 21h
    mov dl, 08h
    int 21h
    ret
backspace endp

cowboy_beep_boop proc            
;-----------------------------BEEP---------------------------------
;http://muruganad.com/8086/8086-assembly-language-program-to-play-s
;ound-using-pc-speaker.html
;comunicando-se com a placa de som com instrucoes in/out
            
;task-list
; 1 - Ligar a saida de som enviando 182 pra porta 43h
; 2 - Ebvuar a frequencia para porta 42h.
; 3 - Para comecar o beep, bits 1 e 0 da porta 61h tem que ser 
; setados para 1.
; 4 - Pausa para duracao do beep
; 5 - Desligar o beep resetando os bits 1 e 0 da porta 61h para 0.
             
    mov al, 182                      ;preparando a saida de som para nota
    out 43h, al 
    mov ax, 1207                         ;frequencia B       (em decimal)
            
    out 42h, al                                   ;byte menor para saida
    mov al, ah                                    ;byte maior para saida
    out 42h, al
    in al, 61h                       ;liga a nota(pega o valor da porta)
    or al, 00000011b                                 ;seta os bits 1 e 0
    out 61h, al                                      ;manda o novo valor
    mov bx, 25                                          ;duracao da nota
    pause1: 
    mov cx, 5000
    pause2:
    dec cx
    jne pause2
    dec bx
    jne pause1
    in al, 61h                                           ;delisga a nota
    and al, 11111100b                               ;resta os bits 1 e 0
    out 61h, al                                      ;manda o novo valor
;-----------------------------------------------------------------------
    ret
cowboy_beep_boop endp

;funcao que verifica se o char em al eh uma letra maiuscula, uma letra
;minuscula, um numero ou nenhum dos anteriores. ele transfere para bl um
;valor que corresponde as possibilidades.
verify_chars proc
    cmp al, 48     ; se for menor que o numero '0'
    jl not_let_num 
    cmp al, 57     ; se for menor ou igual o numero '9'
    jle number     
    cmp al, 65     ; se for menor que a letra 'A'
    jl not_let_num
    cmp al, 90     ; se for menor ou igual que a letra 'Z'
    jle capital_letter
    cmp al, 97     ; se for menor que a letra 'a'
    jl not_let_num 
    cmp al, 122     ; se for menor que a letra 'z'
    jle lowercase_letter
    jmp not_let_num
    number:
        mov bl, 0  ; codigo que diz que e numero
        jmp fim
    lowercase_letter:
        mov bl, 1  ; codigo que diz que e letra minuscula
        jmp fim
    capital_letter:
        mov bl, 2  ; codigo que diz que e letra maiuscula
        jmp fim
    not_let_num:
        mov bl, 3  ; codigo que diz que nao eh letra nem numero, armazenado em bl
        jmp fim
    fim:
        ret
verify_chars endp

;funcao que verifica se o caractere depois do espaco eh uma letra 'o', e se o
;caractere antes do 'o' eh um numero. Caso a resposta seja sim para as duas 
;verificacoes, ele substitui o 'o' pelo 'º' tanto na tela quanto na string, e
;adiciona o espaco no final do buffer independente do caso.
ordinal_number proc
    cmp buff[di-1], o_letter ; verifica se antes do espaco tinha uma letra 'o'
    je verification
    jmp fim_ord

    verification:
        mov al, buff[di-2]  ; char antes da letra 'o'
        call verify_chars
        cmp bl, 0           ; se for numero
        je troca_letra
        jmp fim_ord         ; se nao for numero

    troca_letra:
        dec di              ; muda di pra posicao do 'o'
        mov ax, di
        mov dl, al          ; preparacoes pra set_cursor
        mov dh, 3
        call set_cursor     ; chama set_cursor para voltar ele
        mov dl, ordinal_o   ; preparar pra mudar o 'o' pelo 'º'
        call record_buffer
        jmp fim_ord         ; pula pro fim
        
    fim_ord:
        mov dl, SPACE       ; atualizar o buffer e a string com o espaco
        call record_buffer
        ret
ordinal_number endp


;realiza o loop de leitura do teclado
;di = saida (numero de caracteres lidos)
read proc
    read_char:
    cmp di, 35
        je buff_max
            
        mov ah, 0
        int 16h
            
        ;;;;;;;;;;;verifica os eventos (pressionar ESC, ENTER, BACKSPACE, TAB ou SPACE)
        cmp al, ESC_KEY   ; se apertar esc
        je stop_read_char
            
        cmp al, RET_KEY   ; se apertar enter
        je stop_read_char
            
        cmp al, BACK      ; se apertar backspace
        je perform_backspace
            
        cmp al, TAB_KEY   ; se apertar tab
        je perform_capitals

        cmp al, SPACE     ; se apertar espaco
        je call_ordinal
                          ; nenhum dos casos anteriores? agora grava o caractere lido e o mostra na tela
        mov dl, al        ; manda o caractere para ser impresso e gravado no buffer
        call record_buffer
        jmp read_char     ; leia o proximo caractere

        call_ordinal:     ; label pra pode chamar a funcao que troca o 'o' por 'º'
            call ordinal_number
            jmp read_char
            
        stop_read_char:   ; parar o programa
            call stop
            
        buff_max:             ;se o numero de caracteres exceder 36(35 + ENTER)
            mov dl, 35                                                  ;coluna
            mov dh, 3                                                    ;linha
            call set_cursor
            
            call cowboy_beep_boop ;beeeeeeep
            call backspace
            
            mov ah, 0
            int 16h 
            
             ;verifica os eventos (pressionar ESC, ENTER OU BACKSPACE)
            cmp al, ESC_KEY
            je stop_buff_max
            
            cmp al, RET_KEY
            je stop_buff_max
            
            cmp al, BACK
            jne buff_max
            
            jmp perform_backspace
            
         stop_buff_max: 
            call stop
            
        _clear_out:
            ;coloca o cursor de volta no final
            mov dl, cl
            mov dh, 3
            call set_cursor 
            
            jmp read_char
            
        perform_backspace: 
            cmp di, 0           ;verifica se backspace n foi apertado no comeco
            je read_char
            
            mov ax, di
            dec ax
            
            mov dl, al
            mov dh, 3
            call set_cursor
            call backspace
            mov buff[di],'$'            ;finge que deleta o caractere na string  
                                              ;realiza o movimento de backspace
            
            dec di                                         ;decrementa o indice  
            dec cx                                         ;decrementa cursor     
            jmp read_char
            
        perform_capitals:        ;letras em maiusculo
            mov si, offset buff  ; pega endereco inicial do buffer
            mov al, [si]
                
            mov cx, 0           ; para atualizar a tela
            call verify_chars

            cmp bl, 1           ; se eh minuscula
            je uppercased
            
            laco:
                mov al, [si]
                cmp al, '$'  ; se tiver no final da string
                
                je _clear_out ;a distancia de um jmp para sua label e de no maximo 127 linhas,
                                     ;label intermediaria entre read char e perform_captals
                
                inc si ; proximo indice
                inc cx ; inc da tela
                mov al, [si-1]
                cmp al, SPACE ; se for espaco
                je start_palavra
                cmp al, COMMA ; se for virgula
                je start_palavra
                cmp al, DOT   ; se for ponto
                je start_palavra
                jmp in_palavra

            start_palavra:     ; quando estiver no inicio de uma palavra
                mov al, [si]
                call verify_chars
                cmp bl, 1     ; se for minuscula
                je uppercased
                jmp laco

            in_palavra:       ; se estiver em uma palavra ou tiver passado ela
                mov al, [si]
                call verify_chars
                cmp bl, 2     ; se eh maiuscula
                je lowercased
                jmp laco

            uppercased:       ; transformar em maiuscula
                mov al, [si]
                sub al, capital
                mov [si], al
                
                ;atualiza na tela
                mov dl, cl
                mov dh, 3
                call set_cursor   
                mov dl, al
                call print_c
                
                jmp laco

            lowercased:       ; transformar em minuscula
                mov al, [si]
                add al, capital
                mov [si], al
                
                ;atualiza na tela
                mov dl, cl
                mov dh, 3
                call set_cursor   
                mov dl, al
                call print_c
                 
                jmp laco 

            fim_loop:
                ret 
            
    ret
read endp

stop proc
    mov buff[di],'$'    ;coloca o terminador na string, assim como em C
         
    lea dx, msg2
    mov ah, 9
    int 21h
            
    lea dx, buff
    mov ah, 9
    int 21h
            
    mov ah, 4ch
    int 21h
    ret 
stop endp

main proc                                       ;inicio da execucao do programa
    main_loop:
        mov ax, @data
        mov ds, ax
        lea dx, msg
        mov ah, 9
        int 21h
        lea dx, new_line
        mov ah, 9
        int 21h

        ;;destination index, indice da string onde o caractere sera posicionado
        mov di, 0                             ;contador da posicao do cursor
        mov cx, 0
        call read
main endp                                             ;final da funco principal

end main                                          ;finaliza o programa assembly
