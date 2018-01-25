;--------------------------------------------------------------------------------------------------------------------------------------------;
;  Программа перевода шестнадцатеричной записи в десятичную отформатированную систему счисления
;
; Прототип C-функции:
; void print(char *out_buf, const char *format, const char *hex_number);
;
; Входное шестнадцатеричное число 128-битное, со знаком в двоичном дополнительном коде. Перед числом может быть символ '-', который следует 
; интерпретировать строго как "инвертировать все биты входного числа и добавить 1". Буквы могут быть любого регистра.
;
; Строка формата подобна формату функции sprintf, фозможные флаги:  '-', '+', ' ', '0' и поле ширины (width).
; ОПИСАНИЕ СТРОКИ ФОРМАТА 
; флаги - (необязательно) один или несколько флагов, которые изменяют поведение форматирования:
;   '-' : выравнивание по левому краю внутри поля заданной ширины (по умолчанию по правому краю)
;   '+' : принудительная печать знака + с положительными значениями (по умолчанию знаком дополняются только отрицательные значения)
;   ' ' : не дополненные знаком или отсутствующие численные значения дополняются слева пробелом. Игнорируется, если присутствует флаг +.
;   '0' : при печати чисел в поле заданной ширины заполнение пустоты идёт нулями вместо пробелов. Флаг игнорируется, если присутствует флаг -.
; ширина - (необязательно) целое число (max 32-битное), означающее минимальную ширину поля. Свободное пространство в поле по умолчанию 
;          заполняется пробелами, выравнивание по правому краю. задаётся аргументом типа unsigneg int.
;          (Замечание: задаётся минимальная ширина поля, форматируемое значение никогда не обрезается.)
;
; В выходной буфер должна быть записана ноль-терминированная строка результата без переводов строки или ещё каких-либо лишних символов.
; Конвенция вызова: cdecl. Название функции в .asm файле: _print. 
;
; Пример оформленного c-файла, для тестирования функции 
;
;   #include "stdio.h"
;   extern void print(char *out_buf, const char *format, const char *hex_number);
;   int main()
;   {
;   char *out_buf = malloc(sizeof(char) * 256);
;   char *format = malloc(sizeof(char) * 256);
;   char *hex_number = malloc(sizeof(char) * 34);                      
;   snprintf(format, 256, "%s", "0+-10"); 
;   snprintf(hex_number, 256, "%s", "ffffffffffffffffffffffffffffff21");
;   print(out_buf, format, hex_number);
;   printf("out_buf:%s.\nhex_number:%s\n", out_buf, hex_number);
;   free(format);
;   free(out_buf);
;   free(hex_number);
;   return 0;
;   }
;
;   РАБОТУ ВЫПОЛНИЛ: Студент группы V3316 Богдан Аржевитин 
;--------------------------------------------------------------------------------------------------------------------------------------------;

section .data
    val_count:    dd 0     
    array_val:    times 4 dd 0
    is_neg_sign:  db 0
    flags_arr:    times 4 db 0                      ; [flags_arr]==1 >'-' [flags_arr+1]==1 >'+' [flags_arr+2]==1 >' ' [flags_arr+3]==1 >'0'
    wight:        dd 0                              ; Ширина поля форматирования   

section .text
    global _print
    _print:
        pushad                
        push  ebp
        push  esp                                   ; итого 40

        ; --- Посчитаем кол-во символов и запишем в [val_count] --- 
        mov   eax, dword [esp+40+4*3]               ; Помещаем указатель на строку в EAX
        xor ecx, ecx
    _string_count:
        mov   bl, byte [eax+ecx]                    ; Помещаем в символ в BL
        inc   ecx                                   ; Увеличиваем счетчик ECX на один
        cmp   bl, 0                                 ; Если BL==0, значит строка полностью обработана
        jnz _string_count

        dec   ecx                                   ; Так как пос-ть заканчивается еще одним символом '\0', не учитываем его при подсчете
        mov   [val_count], ecx                      ; Запишем в [val_count] кол-во символов 
        ; ------------------------------------------------------

        ; --- Начнем преобразование  --- 
        ; Проверка на символ инвертирования перед числом '-'
        mov   eax, dword [esp+40+4*3]               ; Помещаем указатель на строку в EAX
        mov   bl, byte [eax]                        ; Помещаем в символ в BL
        cmp   bl, '-'                               ; Перед числом стоит '-', -> нужно потом инвертировать число и уменьшить счетчик символов
        jne _endif_invert
        mov eax, 1                                  ; Запомним, что был символ '-'
        mov [is_neg_sign], eax
        mov eax, [val_count]                        ; Уменьшим [val_count] на один 
        dec eax           
        mov [val_count], eax
    _endif_invert:
        ; Все ок, приступаем к обработке числа
        xor   ecx, ecx
    _string_to_array_val:
        mov   eax, dword [esp+40+4*3]               ; Помещаем указатель на строку в EAX
        add   eax, [is_neg_sign]                    ; Если был символ '-', сдвигаем еще на один байт
        mov   bl, byte [eax+ecx]                    ; Помещаем в символ в BL     

        cmp bl, 0                                   ; Если BL==0, значит строка полностью обработана
        jz _string_is_parsed

        cmp   bl, 57                                ; Если bl > 57, значит это буква 
        jg    _letter_to_dec_bl
        cmp   bl, 48
        jnl   _number_to_dec_bl                     ; Если bl > 47, значит это цифра 
    _back_0:
    
        ; ---  Теперь в bl нормальное число - это очередная цифра hex числа 
        ;      Записываем в array_val это hex число  
        mov   edi, [val_count]   
        dec   edi                                   ; Уменьшим на один, так как индексы начинаются с нуля
        sub   edi, ecx                              ; Теперь в edi хранится правильный индекс цифры 
      
        push  ebx                                   ; Сохраняем значение ebx
        push  ecx                                   ; Сохраняем значение ecx
           
        xor   edx, edx                              ; Обнуляем значения
        mov   dl, bl                                ; Перенесем цифру в младший разряд числа
        xor   ecx, ecx                              ; Обнуляем значения
        xor   ebx, ebx                              ; Обнуляем значения
        xor   eax, eax                              ; Обнуляем значения

    _while_begin:                                   ; Сдвигаем значение очередной hex цифры в регистрах
        cmp   edi, 0
        jle   _while_end

        shld    eax, ebx, 4                         ; Сдвиги на 4 - эквивалентны умножению числа на 16
        shld    ebx, ecx, 4                         ; Кол-во необходимых умножений на 16 определяет индекс числа
        shld    ecx, edx, 4             
        shl     edx, 4

        dec   edi
        jmp   _while_begin
    _while_end:

        add   [array_val+4*3], edx                  ; Переносим результат в переменные числа
        adc   [array_val+4*2], ecx                  ;  
        adc   [array_val+4], ebx                    ;
        adc   [array_val], eax                      ;

        pop   ecx                                   ; Восстанавливаем значения
        pop   ebx                                   ;
        ; -----------------------------------------------------

    _string_to_array_val_inc_ecx:
        inc ecx                                     ; Увеличиваем счетчик ECX на один
        jmp _string_to_array_val
        ; ----------------------------------------------------------------

        ; -- Преобразование символа в bl в корректное число
    _letter_to_dec_bl:
        cmp   bl, 70
        jg    _then                                 ; Если очередная цифра маленькая, преобразуем в заглавную (для дальнейшей удобной работы)
        jmp _else
    _then:
        sub   bl, 32
    _else:
        sub   bl, 55                                ; Теперь в BL лежит действительное значение очередной цифры hex числа
        jmp _back_0

    _number_to_dec_bl:
        sub   bl, 48                                ; Теперь в BL лежит действительное значение очередной цифры hex числа
        jmp _back_0
        ; ------------------------------------------------------

        ; ---------- Определим десятичные цифры числа и запишем их в стек
    _string_is_parsed:
        ; Теперь array_val указывает на переданное число
        xor esi, esi                                ; В esi запишем кол-во dex цифр

      ; ------ Инверсия если нужно 
        mov eax, 1
        cmp   [is_neg_sign], eax
        jne   _no_invese_sign                       ; Если нет знака '-' инвертирования числа, идем дальше
        mov eax, 0                                  ; Убираем бит знака, сейчас он нужен был только для инвертирования, проверка будет потом 
        mov   [is_neg_sign], eax                    ;
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
        mov   [array_val], eax                      ; Теперь array_val - указывает на инвертированное число с добавленной единицей
    _no_invese_sign:

        ; Если полученное число получилось отрицательным (единица в первом бите, инвертируем опять)
        mov   eax, [array_val]
        and   eax, 80000000h
        cmp   eax, 0
        je  _no_invese_bit
        mov   eax, 1                                ; Поместим в is_neg_sign 1, так как число отрицательное
        mov   [is_neg_sign], eax
        jmp   _inverse
    _no_invese_bit:
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
        inc esi                                     ; Подсчитываем кол-во dex символов
        cmp ebx, 0
        jnz _convert_to_literal_and_add_to_stack

        mov [val_count], esi                        ; Сбросим значение счетчика hex цифр, будем использовать его для кол-ва dex чисел   
        ; ---------------------------------------------------
        ; ------ Ну вот и добрались мы до флагов форматирования, кажется это самая отстойная часть кода моей программы 

        add   eax, [val_count]                      ; Помещаем указатель на строку формата в EAX
        mov   ebx, 4                                ; с условием сдвига стека из-за добавленых в него символов
        mul   ebx
        lea   ebx, dword [esp+40+4*2]  
        add   eax, ebx
        mov   eax, [eax]

        mov   dl, 1                                 ; Для установки значения флагов
        xor   ecx, ecx                              ; Храним индекс обрабатываемого символа строки формата
    _string_flag_next_symbol:                       ; Посимвольно считываем флаги из строки, пока не встретим цифру [1-9] либо '\0'
        mov   bl, byte [eax+ecx]                    ; Помещаем в символ в BL
        inc   ecx 

        cmp   bl, 0                                 ; Если BL==0, значит строка полностью обработана
        je   _string_flag_without_wight
        
        cmp   bl, '-'
        jne   _not_flag_0
        mov byte [flags_arr], dl
        jmp _string_flag_next_symbol
    _not_flag_0:
        cmp   bl, '+'
        jne   _not_flag_1
        mov byte [flags_arr+1], dl
        jmp _string_flag_next_symbol
    _not_flag_1:
        cmp   bl, ' '
        jne   _not_flag_2
        mov byte [flags_arr+2], dl
        jmp _string_flag_next_symbol
    _not_flag_2:
        cmp   bl, '0'
        jne   _not_flag_3
        mov byte [flags_arr+3], dl
        jmp _string_flag_next_symbol
    _not_flag_3:
        
    ; Если очередной символ не один из символов флагов, значит это первая цифра поля ширины (wight)
    ; Подсчитаем кол-во символов поля wight, в edx будем хранить это кол-во символов 
        xor edx, edx
        dec ecx                                     ; Сдвинем на верную позицию
    _string_wight_count_symbol:   
        inc   edx                                   ; Так как сейчас eax+ecx уже указывает на первый символ поля (wight), учтем это   
        mov   bl, byte [eax+ecx]  
        inc   ecx
        cmp   bl, 0                                 ; Если BL==0, значит строка полностью обработана
        jne   _string_wight_count_symbol

        dec   edx
        dec   ecx                                   ; Теперь eax+ecx будет указывать на последний символ поля (wight)
        add   eax, ecx                              ; Теперь eax будет указывать на последний символ поля (wight)
        dec   eax

        ; Преобразуем поле (wight) к DEC и запишем в переменную [wight]
        xor   esi, esi                              ; В esi храним тещую итерацию цикла для правильного умножения  
        xor   ebx, ebx
        mov   edi, eax                              ; В edi временно будем хранить текущий адрес символа поля (wight)

    _string_wight_symbol_to_val:   
        push  edx                                   ; Запомним кол-во смволов оставшегося поля (wight)
        mov   bl, byte [edi]  
        sub   bl, 48                                ; Преобразуем bl к dec числу
      
        mov   eax, ebx                              ; Переместим в eax значение ebx для последующего умножения на 10 в степени 
        mov   ecx, esi                              ; Счетчик цикла возведения 10 в степень esi
    _loop_mul_10_start:
        cmp   ecx, 0
        je    _loop_mul_10_end
        dec   ecx
        mov   edx, 10
        mul   edx   
        jmp _loop_mul_10_start                      ; Теперь eax правильно умноженная цифра числ
    _loop_mul_10_end:

        add   [wight], eax                          ; Добавим очередную цифру
      
        inc   esi
        dec   edi
        pop   edx                                   ; Восстановим значение кол-ва смволов поля (wight)
        dec   edx
        jnz   _string_wight_symbol_to_val

    _string_flag_without_wight:
        ; Обработка завершена, в [widgt] размер поля, во [flags_arr..] значения требуемых флагов
    

        ; ------ Запись в [out_buffer] строки из стека
        mov   esi, [val_count]
        mov   eax, [esp+40+4+esi*4]                 ; в eax указатель на out_buffer (esi*4 - т.к. в стеке уже есть цифры)

        xor ecx, ecx                                ; Счетчик текущего индекса [eax+ecx] для записи в строку 

        ; Добавление символа перед числом 
        mov dl, 1             
        cmp byte [flags_arr+2], dl
        jne _skip_flag_2
        mov bl, ' '
    _skip_flag_2: 
        cmp byte [flags_arr+1], dl
        jne _skip_flag_1
        mov bl, '+'
    _skip_flag_1:
     
        cmp byte [is_neg_sign], dl
        jne _skip_neg_sign
        mov bl, '-'
    _skip_neg_sign:

        xor dh, dh                                  ; Проверка на то, были ли установлены флаги установки символа перед числом
        add dh, byte [flags_arr+1]
        add dh, byte [flags_arr+2]
        add dh, byte [is_neg_sign]
        cmp dh, 0                                   ; Если значение не 0, то были установлены флаги установки символа перед числом
        jz _skip_inc_ecx
        mov [eax], bl                               ; Запись символа перед числом
        inc ecx                                     ; Увеличим счетчик символов на один
        add [val_count], dl                         ; Добавляем еще один символ
    _skip_inc_ecx:
   
        ; ---- Добавим в строку символ заполнитель 
        ;;;; Установлен flag_0 -> '-' ?    
        cmp byte [flags_arr], dl      
        jne _no_flag_2
        ; Запишем число со знаком
    _loop_write_to_out_buf_1:   
        pop ebx                                     ; в ebx находится десятичное число
        add ebx, 48                                 ; преобразуем в ascii код 
        mov [eax+ecx], bl                           ; Запись очередного символа с необходимым сдвигом out_buff
        inc ecx
        cmp ecx, [val_count]
        jl _loop_write_to_out_buf_1
        ; Запишем заполнение
    _loop_write_to_out_placeholder_1:   
        cmp ecx, [wight]
        jge _end_string_parse
        mov bl, ' '                      
        mov [eax+ecx], bl               
        inc ecx      
        jmp _loop_write_to_out_placeholder_1
    _no_flag_2: 

        ;;;; Установлен flag_3 -> '0' ?
        cmp byte [flags_arr+3], dl    
        jne _no_flag_3
        mov esi, [wight]                            ; Проверим ширину поля 
        cmp esi, [val_count]
        jg _ok_2
        mov esi, [val_count]
        jmp _loop_write_to_out_buf_2                ; Установленная ширина поля мала
    _ok_2:  
        sub esi, [val_count]                        ; Теперь в esi кол-во требующихся символов заполнителей '0' для печати перед числом 

        cmp dh, 0                                   ; Если значение не 0, то были установлены флаги установки символа перед числом
        jz _no_eny_sign
        inc esi
    _no_eny_sign:

        ; Запишем заполнение
    _loop_write_to_out_placeholder_2:   
        mov bl, '0'                      
        mov [eax+ecx], bl               
        inc ecx
        cmp ecx, esi
        jl _loop_write_to_out_placeholder_2

        add esi, [val_count]                        ; Запишем в esi общую длину символов числа для вывода
        ; Проверка на то, есть ли любой спец знак перед числом 
        cmp dh, 0                                   ; Если значение не 0, то были установлены флаги установки символа перед числом
        jz _no_eny_sign3
        dec esi
    _no_eny_sign3:

        ; Запишем число со знаком
    _loop_write_to_out_buf_2:   
        pop ebx                                     ; в ebx находится десятичное число
        add ebx, 48                                 ; преобразуем в ascii код 
        mov [eax+ecx], bl                           ; Запись очередного символа с необходимым сдвигом out_buff
        inc ecx
        cmp ecx, esi
        jl _loop_write_to_out_buf_2
        jmp _end_string_parse
    _no_flag_3: 

        ;;;; Если   flag_0 и  flag_3 не установлены
        mov esi, [wight]                            ; Проверим ширину поля 
        cmp esi, [val_count]
        jg _ok_3
        mov esi, [val_count]
        cmp dh, 0                                   ; Проверка на то, есть ли любой спец знак перед числом
        jz _no_eny_sign13
    _no_eny_sign13:
        jmp _loop_write_to_out_buf_3                ; Установленная ширина поля мала
    _ok_3:
        sub esi, [val_count]                        ; Теперь в esi кол-во требующихся символов заполнителей '0' для печати перед числом 
  
        cmp dh, 0                                   ; Проверка на то, есть ли любой спец знак перед числом
        jz _no_eny_sign1
        mov bh, [eax]                               ; теперь в bh лежит знак
        dec ecx
    _no_eny_sign1:
    
        ; Запишем заполнение
    _loop_write_to_out_placeholder_3:   
        mov bl, ' '                      
        mov [eax+ecx], bl               
        inc ecx
        cmp ecx, esi
        jl _loop_write_to_out_placeholder_3
    
        add esi, [val_count]
        cmp dh, 0                                   ; Запись спец знака перед числом
        jz _no_eny_sign2
        mov [eax+ecx], bh               
        inc ecx
    _no_eny_sign2:

        ;Запишем число со знаком
    _loop_write_to_out_buf_3:    
        pop ebx                                     ; в ebx находится десятичное число
        add ebx, 48                                 ; преобразуем в ascii код 
        mov [eax+ecx], bl                           ; Запись очередного символа с необходимым сдвигом out_buff
        inc ecx
        cmp ecx, esi
        jl _loop_write_to_out_buf_3

    _end_string_parse:

        mov   bl, 0                                 ; Закончим строку символом \0
        mov   [eax+ecx], bl
        ; ------------------------------------------------------
        pop   esp
        pop   ebp    
        popad 
    ret 