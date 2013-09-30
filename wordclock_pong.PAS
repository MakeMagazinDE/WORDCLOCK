program wordclock;

{$NOSHADOW}
{ $WG}                     {global Warnings off}

{$DEFINE PONGBOARD} // mit Original-Matrix 11 x 10, sonst 12 x 12


Device = mega8, VCC=5;
{ $BOOTRST $00C00}         {Reset Jump to $00C00}

Define_Fuses
//  Override_Fuses;
  NoteBook   = A;
  COMport    = USB;
  LockBits0 = [];
  FuseBits0  = [CKSEL0, CKSEL1, CKSEL3, SUT0, BODEN];
  FuseBits1  = [];
  ProgMode   = SPI;
  ProgFuses  = true;
  ProgLock   = false;
  ProgFlash  = true;
  ProgEEprom = false;

Import SysTick, TWImaster, RTClock, TickTimer;
{$IFNDEF PONGBOARD}
// Import DCFclock;
{$ENDIF}

From System Import LongWord, Random;


Define
  ProcClock      = 8000000;       {Hertz}
  SysTick        = 10;             {msec}
  StackSize      = $0032, iData;
  FrameSize      = $0032, iData;
{$IFNDEF PONGBOARD}
//  DCFclock       = iData;
//  DCFport        = PinB, 2, positive; {Port, Pin#, Polarity}
{$ENDIF}
  TWIpresc       = TWI_BR100;
  TickTimer      = Timer1;
  RTClock        = iData, Time;
  RTCsource      = SysTick;
  
Implementation

{$IDATA}

{--------------------------------------------------------------}
{ Type Declarations }

type


{--------------------------------------------------------------}
{ Const Declarations }
const
{$IFDEF PONGBOARD}
  sr_on: Boolean = false;
  sr_off: Boolean = true;
 {$ELSE}
  sr_on: Boolean = false;
  sr_off: Boolean = true;
{$ENDIF}
  rtc_adr: byte = $68;
  
{--------------------------------------------------------------}
{ Var Declarations }
var
{$PDATA}

{$IFDEF PONGBOARD}
  SR_CLK[@PortB,3]: Bit;
  SR_DATA[@PortB,4]: Bit;
  SR_STRB[@PortB,2]: Bit;
  HOURBTN[@PinD,0]: Bit;
  MINUTEBTN[@PinD,1]: Bit;
  TESTPIN[@PortD,3]: Bit;
{$ELSE}
  SR_CLK[@PortB,5]: Bit;
  SR_DATA[@PortB,3]: Bit;
  HOURBTN[@PinB,1]: Bit;
  MINUTEBTN[@PinB,0]: Bit;
  TESTPIN[@PortB,4]: Bit;
{$ENDIF}


{$DATA}
  b, i, led_row, tenmillisec: byte;
{$IDATA}
  TickSema, Blinkenlights,
  SecondSema, MinuteSema, LEDupdateRequest: Boolean;

  LED_array: Array[0..11,0..11] of boolean;
  LED_array_all[@LED_array]: Array[0..143] of boolean;
  LED_word_array: Array[0..11] of word;

  LED_word: word;
  UpdateTimer: SysTimer8;
  BlinkTimer, LED_select,
  hour, minute: Byte;

{--------------------------------------------------------------}
{ functions }

procedure onTickTimer;
begin
  TickSema:= true;
end;

procedure RTCtickMinute;
begin
  MinuteSema:= true;
end;

procedure RTCtickSecond;
begin
  SecondSema:= true;
end;

function DS1307getSecond: byte;
var my_byte: byte;
begin
  TWIout(rtc_adr,0); // Sekunden-Register
  TWIinp(rtc_adr,my_byte);
  return(BCDtoByte(my_byte));
end;

function DS1307getMinute: byte;
var my_byte: byte;
begin
  TWIout(rtc_adr,1); // Minuten-Register
  TWIinp(rtc_adr,my_byte);
  return(BCDtoByte(my_byte));
end;

function DS1307getHour: byte;
var my_byte: byte;
begin
  TWIout(rtc_adr,2); // Stunden-Register
  TWIinp(rtc_adr,my_byte);
  return(BCDtoByte(my_byte and $3F));
end;

procedure DS1307setSecond(my_second: byte);
var my_byte: byte;
begin
  my_Byte:= ByteToBCD(my_second) and $7F; // Clock HALT Bit immer löschen
  TWIout(rtc_adr,0,my_Byte); // Minuten-Register
end;

procedure DS1307setMinute(my_minute: byte);
var my_byte: byte;
begin
  my_Byte:= ByteToBCD(my_Minute);
  TWIout(rtc_adr,1,my_Byte); // Minuten-Register
end;

procedure DS1307setHour(my_hour: byte);
var my_byte: byte;
begin
  my_Byte:= ByteToBCD(my_hour);
  TWIout(rtc_adr,2,my_Byte); // Minuten-Register
end;

//##############################################################################

procedure InitPorts;
begin
{$IFDEF PONGBOARD}
  PortB:= %00000000;
  DDRB:=  %00011111;

  PortC:= %00000000;
  DDRC:=  %00001111;

  PortD:= %00000111;
  DDRD:=  %11111000;
{$ELSE}
  PortB:= %00000111;
  DDRB:=  %00111000;
  
  PortC:= %00000000;
  DDRC:=  %00001111;

  PortD:= %00000000;
  DDRD:=  %11111111;
{$ENDIF}
end InitPorts;

procedure LED_out;
begin
{$IFDEF PONGBOARD}
   PortC:=(PortC and $F0) or (lo(LED_word) and $0F);
   PortD:=(PortD and $0F) or (lo(LED_word) and $F0);
   PortB:=(PortB and $FC) or (hi(LED_word) and $03);
{$ELSE}
   PortC:=hi(LED_word) and $0F;
   PortD:=lo(LED_word);
{$ENDIF}
end;

procedure LED_off;
begin
{$IFDEF PONGBOARD}
   PortC:=(PortC and $F0);
   PortD:=(PortD and $0F);
   PortB:=(PortB and $FC);
{$ELSE}
   PortC:=(PortC and $F0);
   PortD:=0;
{$ENDIF}
end;


procedure LED_SR_next;
begin
  if not inctolim(led_row, 11) then
    led_row:= 0;
    SR_DATA:= sr_on;
    SR_CLK:= true;
    nop; nop; nop;
    SR_CLK:= false;
    SR_DATA:= sr_off;
    LED_word:= LED_word_array[0];
  else
    SR_CLK:= true;
    nop; nop; nop;
    SR_CLK:= false;
  endif;
  LED_off;
{$IFDEF PONGBOARD}
  SR_STRB:= true;
  nop; nop; nop;
  SR_STRB:= false;
{$ENDIF}
  LED_word:= LED_word_array[led_row];
  LED_out;
end;

//##############################################################################

procedure LED_array_to_words(my_LEDs: byte);
var my_word: word;
begin
  my_word:=0;
{$IFDEF PONGBOARD}
  for b:= 0 to 11 do
    if LED_array[b,my_LEDs] then // einzelne Bits setzen
      incl(my_word,b);
    endif;
  endfor;
  LED_word_array[my_LEDs]:= my_word;
{$ELSE}
  for b:= 0 to 11 do
    if LED_array[my_LEDs,b] then // einzelne Bits setzen
      incl(my_word,b);
    endif;
  endfor;
  LED_word_array[my_LEDs]:= my_word;
{$ENDIF}
end;

procedure Letter_on(my_first_letter, my_last_letter: byte; my_letter_on: boolean);
//  LED_array[0,0]:= true;  // Zeile, Spalte oben links
//  LED_array[9,11]:= true; // Zeile, Spalte unten rechts bei Pong-Platine
var my_line, my_start, my_end: byte;
begin
{$IFDEF PONGBOARD}
  my_line:= my_first_letter div 11;
  my_start:= my_first_letter mod 11;
  my_end:= my_last_letter mod 11;
{$ELSE}
  my_line:= my_first_letter div 12;
  my_start:= my_first_letter mod 12;
  my_end:= my_last_letter mod 12;
{$ENDIF}
  for b:= my_start to my_end do
    LED_array[my_line,b]:= my_letter_on;
  endfor;
end;

procedure time_to_letters(my_hour, my_minute: byte; my_adjust: boolean);
var my_div, my_mod, my_addhour: byte;
begin
  for i:= 0 to 143 do
    LED_array_all[i]:= false;
  endfor;
{$IFDEF PONGBOARD}
  Letter_on(0,1,true); // es
  Letter_on(3,5,true); // ist
  my_mod:= my_minute mod 5;
// Minute words
  my_addhour:= 0;
  my_div:= my_minute div 5;
  my_hour:= my_hour mod 12;
  if my_adjust then
    case my_mod of // Einzel-Minuten
      0:
          LED_array_all[11]:= true; // +1
          |
      1:
          LED_array_all[23]:= true; // +1
          |
      2:
          LED_array_all[35]:= true; // +1
          |
      3:
          LED_array_all[47]:= true; // +1
          |
      4:
          LED_array_all[59]:= true; // +1
          |
    endcase;
  endif;
  case my_div of
    0:
        Letter_on(107,109,true);  // Uhr
        |
    1:
        Letter_on(7,10,true);  // fünf
        Letter_on(40,43,true); // nach
        |
    2:
        Letter_on(11,14,true); // zehn
        Letter_on(40,43,true); // nach
        |
    3:
        Letter_on(26,32,true); // viertel
        Letter_on(40,43,true); // nach
        |
    4:
        Letter_on(15,21,true); // zwanzig
        Letter_on(40,43,true); // nach
        |
    5:
        Letter_on(7,10,true);  // fünf
        Letter_on(33,35,true); // vor
        Letter_on(44,47,true); // halb
        my_addhour:= 1;
        |
    6:
        Letter_on(44,47,true); // halb
        my_addhour:= 1;
        |
    7:
        Letter_on(7,10,true);  // fünf
        Letter_on(40,43,true); // nach
        Letter_on(44,47,true); // halb
        my_addhour:= 1;
        |
    8:
        Letter_on(15,21,true); // zwanzig
        Letter_on(33,35,true); // vor
        my_addhour:= 1;
        |
    9:
        Letter_on(22,32,true); // dreiviertel
        my_addhour:= 1;
        |
    10:
        Letter_on(11,14,true); // zehn
        Letter_on(33,35,true); // vor
        my_addhour:= 1;
        |
    11:
        Letter_on(7,10,true);  // fünf
        Letter_on(33,35,true); // vor
        my_addhour:= 1;
        |
  endcase;
  my_hour:= my_hour + my_addhour;

  if (my_div > 0) and (my_hour = 1) then
    Letter_on(58,58,true);  // Sonderfall ein"s"
  endif;
  case my_hour of
    0,12:
      Letter_on(94,98,true);
      |
    1,13:
      Letter_on(55,57,true);
      |
    2,14:
      Letter_on(62,65,true);
      |
    3,15:
      Letter_on(66,69,true);
      |
    4,16:
      Letter_on(73,76,true);
      |
    5,17:
      Letter_on(51,54,true);
      |
    6,18:
      Letter_on(77,81,true);
      |
    7,19:
      Letter_on(88,93,true);
      |
    8,20:
      Letter_on(84,87,true);
      |
    9,21:
      Letter_on(102,105,true);
      |
    10,22:
      Letter_on(99,102,true);
      |
    11,23:
      Letter_on(49,51,true);
      |
  endcase;
  
  
{$ELSE}

  Letter_on(0,1,true); // es
  Letter_on(3,5,true); // ist
  my_mod:= my_minute mod 5;
// Minute words
  my_addhour:= 0;
  my_div:= my_minute div 5;
  my_hour:= my_hour mod 12;
  if my_adjust then
    case my_mod of // Einzel-Minuten
      0:
          LED_array_all[11]:= true; // +1
          |
      1:
          LED_array_all[23]:= true; // +1
          |
      2:
          LED_array_all[35]:= true; // +1
          |
      3:
          LED_array_all[47]:= true; // +1
          |
      4:
          LED_array_all[59]:= true; // +1
          |
    endcase;
  endif;
  case my_div of
    0:
        Letter_on(107,109,true);  // Uhr
        |
    1:
        Letter_on(7,10,true);  // fünf
        Letter_on(40,43,true); // nach
        |
    2:
        Letter_on(11,14,true); // zehn
        Letter_on(40,43,true); // nach
        |
    3:
        Letter_on(26,32,true); // viertel
        Letter_on(40,43,true); // nach
        |
    4:
        Letter_on(15,21,true); // zwanzig
        Letter_on(40,43,true); // nach
        |
    5:
        Letter_on(7,10,true);  // fünf
        Letter_on(33,35,true); // vor
        Letter_on(44,47,true); // halb
        my_addhour:= 1;
        |
    6:
        Letter_on(44,47,true); // halb
        my_addhour:= 1;
        |
    7:
        Letter_on(7,10,true);  // fünf
        Letter_on(40,43,true); // nach
        Letter_on(44,47,true); // halb
        my_addhour:= 1;
        |
    8:
        Letter_on(15,21,true); // zwanzig
        Letter_on(33,35,true); // vor
        my_addhour:= 1;
        |
    9:
        Letter_on(22,32,true); // dreiviertel
        my_addhour:= 1;
        |
    10:
        Letter_on(11,14,true); // zehn
        Letter_on(33,35,true); // vor
        my_addhour:= 1;
        |
    11:
        Letter_on(7,10,true);  // fünf
        Letter_on(33,35,true); // vor
        my_addhour:= 1;
        |
  endcase;
  my_hour:= my_hour + my_addhour;

  if (my_div > 0) and (my_hour = 1) then
    Letter_on(58,58,true);  // Sonderfall ein"s"
  endif;
  case my_hour of
    0,12:
      Letter_on(94,98,true);
      |
    1,13:
      Letter_on(55,57,true);
      |
    2,14:
      Letter_on(62,65,true);
      |
    3,15:
      Letter_on(66,69,true);
      |
    4,16:
      Letter_on(73,76,true);
      |
    5,17:
      Letter_on(51,54,true);
      |
    6,18:
      Letter_on(77,81,true);
      |
    7,19:
      Letter_on(88,93,true);
      |
    8,20:
      Letter_on(84,87,true);
      |
    9,21:
      Letter_on(102,105,true);
      |
    10,22:
      Letter_on(99,102,true);
      |
    11,23:
      Letter_on(49,51,true);
      |
  endcase;
{$ENDIF}
end;

{--------------------------------------------------------------}
{ Main Program }
{$IDATA}

begin
  InitPorts;
  TickTimerTime(1000);  // Wert in us
  TickTimerStart;
  Blinkenlights:= true;
  BlinkTimer:= 20;
  
  EnableInts;
  MinuteSema:= true;
  i:= DS1307getSecond;  // First Power up, Clock HALT Bit löschen
  DS1307setSecond(i);

  loop
    if TickSema then
      TickSema:=false;
      TESTPIN:= not TESTPIN;
      LED_SR_next;
    endif;

    if MinuteSema then
      Blinkenlights:= true;
      BlinkTimer:= 10;
      MinuteSema:= false;
      minute:= DS1307getMinute;
      hour:= DS1307getHour;
      time_to_letters(hour, minute,false);
      LEDupdateRequest:= true;
    endif;
    
    if SecondSema then
      SecondSema:= false;
      if not HOURBTN then // neg. Logik!
        inctolimwrap(hour,11,0);
        DS1307setHour(hour);
        DS1307setSecond(0);
        RTCsetHour(hour);
        RTCsetSecond(0);
        time_to_letters(hour, minute, true);
        LEDupdateRequest:= true;
        Blinkenlights:= false;
      endif;
      if not MINUTEBTN then // neg. Logik!
        inctolimwrap(minute,59,0);
        DS1307setMinute(minute);
        DS1307setSecond(0);
        RTCsetMinute(minute);
        RTCsetSecond(0);
        time_to_letters(hour, minute, true);
        LEDupdateRequest:= true;
        Blinkenlights:= false;
      endif;
    endif;
    
    if Blinkenlights then
      if isSysTimerZero(UpdateTimer) and Blinkenlights then
        setSysTimer(UpdateTimer, lo(randomrange(5,15)));
        for i:= 0 to 11 do
          LED_word_array[i]:= LED_word_array[i] + (random and $FF);
        endfor;
        if not dectolim(BlinkTimer, 0) then
          Blinkenlights:= false;
        endif;
      endif;
    else
      if LEDupdateRequest then
        for LED_select := 0 to 11 do
          LED_array_to_words(LED_select);
        endfor;
        LEDupdateRequest:= false;
//        inctolimwrap(LED_select,11,0);    // Alternativ Round-Robin
      endif;
    endif;

  endloop;
end wordclock.

