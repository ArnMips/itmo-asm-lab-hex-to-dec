;-----------------------------------------------;
;  This program                                 ;
;-----------------------------------------------;

extern _printf

section .data
  val_count:    dd 0     
  array_val:    times 4 dd 0
  is_neg_sign:  db 0

section .text
  global _test_asm
  _test_asm:
    pushad
    push  ebp
    push  esp     ; итого 40

    ; --- Посчитаем кол-во символов и запишем в [val_count] --- 
    mov   eax, dword [esp+40+4*2]  ; Помещаем указатель на строку в EAX
    xor ecx, ecx
    _string_count:
      mov   bl, byte [eax+ecx]         ; Помещаем в символ в BL
      inc   ecx                         ; Увеличиваем счетчик ECX на один
      cmp   bl, 0                       ; Если BL==0, значит строка полностью обработана
    jnz _string_count

    dec   ecx                         ; Так как пос-ть заканчивается еще одним символом '\0', не учитываем его при подсчете
    mov   [val_count], ecx      ; Запишем в [val_count] кол-во символов 
    ; ------------------------------------------------------

    ; --- Начнем преобразование  --- 
    ; Проверка на символ инвертирования перед числом '-'
    mov   eax, dword [esp+40+4*2]  ; Помещаем указатель на строку в EAX
    mov   bl, byte [eax]         ; Помещаем в символ в BL
    cmp   bl, '-'                     ; Перед числом стоит '-', значит нужно потом инвертировать число и уменьшить счетчик символов
    jne _endif_invert
      mov eax, 1                  ; Запомним, что был символ '-'
      mov [is_neg_sign], eax
      mov eax, [val_count]        ; Уменьшим [val_count] на один 
      dec eax           
      mov [val_count], eax
    _endif_invert:


    ; Все ок, приступаем к обработке числа
    xor   ecx, ecx
    _string_to_array_val:
      mov   eax, dword [esp+40+4*2]         ; Помещаем указатель на строку в EAX
      add   eax, [is_neg_sign]              ; Если был символ '-', сдвигаем еще на один байт
      mov   bl, byte [eax+ecx]              ; Помещаем в символ в BL     

      cmp bl, 0                       ; Если BL==0, значит строка полностью обработана
      jz _string_is_parsed

      cmp   bl, 57                     ; Если bl > 57, значит это буква 
      jg    _letter_to_dec_bl
      cmp   bl, 48
      jnl   _number_to_dec_bl          ; Если bl > 47, значит это цифра 
      _back_0:


      ; ---  Теперь в bl нормальное число - это очередная цифра hex числа 
      ;      Записываем в array_val это hex число  
      mov   edi, [val_count]   
      dec   edi                        ; Уменьшим на один, так как индексы начинаются с нуля
      sub   edi, ecx                   ; Теперь в edi хранится правильный индекс цифры 
      
      push  ebx                        ; Сохраняем значение ebx
      push  ecx                        ; Сохраняем значение ecx
           
      xor   edx, edx                   ; Обнуляем значения
      mov   dl, bl                     ; Перенесем цифру в младший разряд числа
      xor   ecx, ecx                   ; Обнуляем значения
      xor   ebx, ebx                   ; Обнуляем значения
      xor   eax, eax                   ; Обнуляем значения

      _while_begin:                     ; Сдвигаем значение очередной hex цифры в регистрах
        cmp   edi, 0
        jle   _while_end

        shld    eax, ebx, 4             ; Сдвиги на 4 - эквивалентны умножению числа на 16
        shld    ebx, ecx, 4             ; Кол-во необходимых умножений на 16 определяет индекс числа
        shld    ecx, edx, 4             
        shl     edx, 4

        dec   edi
        jmp   _while_begin
      _while_end:

      add   [array_val+4*3], edx        ; Переносим результат в переменные числа
      adc   [array_val+4*2], ecx        ;  
      adc   [array_val+4], ebx          ;
      adc   [array_val], eax            ;

      pop   ecx                         ; Восстанавливаем значения
      pop   ebx                         ;
      ; -----------------------------------------------------

      _string_to_array_val_inc_ecx:
        inc ecx                         ; Увеличиваем счетчик ECX на один
    jmp _string_to_array_val
    ; ----------------------------------------------------------------

    ; -- Преобразование символа в bl в корректное число
    _letter_to_dec_bl:
      cmp   bl, 70
      jg    _then                     ; Если очередная цифра маленькая, преобразуем в заглавную (для дальнейшей удобной работы)
      jmp _else
      _then:
        sub   bl, 32
      _else:
      sub   bl, 55                    ; Теперь в BL лежит действительное значение очередной цифры hex числа
    jmp _back_0

    _number_to_dec_bl:
      sub   bl, 48                    ; Теперь в BL лежит действительное значение очередной цифры hex числа
    jmp _back_0
    ; ------------------------------------------------------

    ; ---------- Определим десятичные цифры числа и запишем их в стек
    _string_is_parsed:
      ; Теперь array_val указывает на переданное число
      xor esi, esi              ; В esi запишем кол-во dex цифр

      ; ------ Инверсия если нужно 
      nop
      nop
      nop

      mov eax, 1
      cmp   [is_neg_sign], eax
      jne   _no_invese_sign       ; Если нет знака '-' инвертирования числа, идем дальше
        mov eax, 0                ; Убираем бит знака, сейчас он нужен был только для инвертирования, проверка будет потом 
        mov   [is_neg_sign], eax  ;
        _inverse:   
        mov   eax, [array_val]
        mov   ebx, [array_val+4]
        mov   ecx, [array_val+4*2]
        mov   edx, [array_val+4*3]
        not   eax
        not   ebx
        not   ecx
        not   edx       
        add   edx, 1
        adc   ecx, 0
        adc   ebx, 0
        adc   eax, 0                         
        mov   [array_val+4*3], edx        
        mov   [array_val+4*2], ecx          
        mov   [array_val+4], ebx          
        mov   [array_val], eax            ; Теперь array_val - указывает на инвертированное число с добавленной единицей
      _no_invese_sign:

        ; Если полученное число получилось отрицательным (единица в первом бите, инвертируем опять)
        mov   eax, [array_val]
        and   eax, 80000000h
        cmp   eax, 0
        je  _no_invese_bit
          mov   eax, 1                ; Поместим в is_neg_sign 1, так как число отрицательное
          mov   [is_neg_sign], eax
          jmp   _inverse
        _no_invese_bit:
          ;mov   eax, 0                ; Поместим в is_neg_sign 0, так как число не отрицательное
          ;mov   [is_neg_sign], eax

      _convert_to_literal_and_add_to_stack:
        xor ebx, ebx
        xor ecx, ecx
        xor edx, edx

        _loop_convert_to_literal:
          mov   eax, [array_val + ecx*4]
          mov   edi, 10
          div   edi
          mov   [array_val + ecx*4], eax
          or    ebx, eax
          inc ecx
          cmp ecx, 4
        jne _loop_convert_to_literal

        push edx
        inc esi                        ; Подсчитываем кол-во dex символов
        cmp ebx, 0
      jnz _convert_to_literal_and_add_to_stack

      mov [val_count], esi              ; Сбросим значение счетчика hex цифр, будем использовать его для кол-ва dex чисел   
      ; ---------------------------------------------------


      ; ------ Запись в [out_buffer] строки из стека
      mov   eax, [esp+40+4+esi*4]             ; в eax указатель на out_buffer (esi*4 - т.к. в стеке уже есть цифры)

      xor ecx, ecx                      ; Счетчик для цикла _loop_write_to_out_buf

      mov edx, 1             ; Проверка, нужно ли писать символ минуса перед числом?
      cmp [is_neg_sign], edx
      jne _loop_write_to_out_buf
        mov bl, '-'
        mov [eax], bl               ; Запись запись минуса перед числом
        inc ecx                         ; Увеличим счетчик символов на один
        add [val_count], edx       ; Добавляем еще один символ

      _loop_write_to_out_buf:
        pop ebx                           ; в ebx находится десятичное число
        add ebx, 48                       ; преобразуем в ascii код 
        mov [eax+ecx], bl               ; Запись очередного символа с необходимым сдвигом out_buff
        inc ecx
        cmp ecx, [val_count]
      jl _loop_write_to_out_buf

      mov   bl, 0                         ; Закончим строку символом \0
      mov   [eax+ecx], bl

    ; ------------------------------------------------------

    pop   esp
    pop   ebp    
    popad 
  ret 