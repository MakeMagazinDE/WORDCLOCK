program wordclock;
// Wordclock-Version f�r c't Wordclock-Platine (Segor-Bausatz)
// Q&D Version basiert auf WordClock f�r PONG, aber verbesserte Buchstaben-Kodierung
// C. Meyer 7/2013

{$NOSHADOW}
{ $WG}                     {global Warnings off}

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
// Import DCFclock;

From System Import LongWord, Random;


Define
  ProcClock      = 8000000;       {Hertz}
  SysTick        = 10;             {msec}
  StackSize      = $0032, iData;
  FrameSize      = $0032, iData;
//  DCFclock       = iData;
//  DCFport        = PinB, 2, positive; {Port, Pin#, Polarity}
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
  sr_on: Boolean = false;
  sr_off: Boolean = true;
  rtc_adr: byte = $68;

// Buchstaben-Pattern, 12 Bit wie angezeigt, plus Zeile im obersten Nibble
  c_es_war: word   = $0000 or %110111000000;
  c_es_ist: word   = $0000 or %110000111000;
  c_gleich: word   = $1000 or %111111000000;
  c_genau: word    = $1000 or %000000011111;
  c_gerade: word   = $2000 or %111111000000;
  c_fuenfmin: word = $2000 or %000000011110;
  c_viertel: word  = $3000 or %000011111110;
  c_dreiviertel: word  = $3000 or %111111111110;
  c_zehnmin: word  = $4000 or %111100000000;
  c_zwanzig: word  = $4000 or %000001111111;
  c_nach: word     = $5000 or %111100000000;
  c_vor: word      = $5000 or %000011100000;
  c_halb: word     = $5000 or %000000001111;
  c_drei: word     = $6000 or %111100000000;
  c_ein: word      = $6000 or %001110000000;
  c_eins: word     = $6000 or %001111000000;
  c_sieben: word   = $6000 or %000001111110;
  c_elf: word      = $7000 or %111000000000;
  c_fuenf: word    = $7000 or %001111000000;
  c_zwoelf: word   = $7000 or %000000011111;
  c_vier: word     = $8000 or %111100000000;
  c_zwei: word     = $8000 or %000011110000;
  c_acht: word     = $8000 or %000000001111;
  c_neun: word     = $9000 or %011110000000;
  c_sechs: word    = $9000 or %000000111110;
  c_zehn: word     = $A000 or %111100000000;
  c_uhr: word      = $A000 or %000001110000;
  c_vor12: word    = $A000 or %000000000111;
  c_nach12: word   = $B000 or %111100000000;
  c_nachts: word   = $B000 or %111111000000;
  c_mittag: word   = $B000 or %000000111111;

{--------------------------------------------------------------}
{ Var Declarations }
var
{$PDATA}
  SR_CLK[@PortB,5]: Bit;
  SR_DATA[@PortB,3]: Bit;
  HOURBTN[@PinB,1]: Bit;
  MINUTEBTN[@PinB,0]: Bit;
  TESTPIN[@PortB,4]: Bit;


{$DATA}
  b, i, led_row, tenmillisec: byte;
  LED_word: word;

{$IDATA}
  TickSema, Blinkenlights,
  SecondSema, MinuteSema, LEDupdateRequest: Boolean;

  LED_word_array: Array[0..11] of word;
// Einzel-Zeilen, evt. einmal gebraucht
  LED_word_line0[@LED_word_array+0]: word;
  LED_word_line1[@LED_word_array+24]: word;
  LED_word_line2[@LED_word_array+48]: word;
  LED_word_line3[@LED_word_array+72]: word;
  LED_word_line4[@LED_word_array+96]: word;
  LED_word_line5[@LED_word_array+120]: word;
  LED_word_line6[@LED_word_array+144]: word;
  LED_word_line7[@LED_word_array+168]: word;
  LED_word_line8[@LED_word_array+192]: word;
  LED_word_line9[@LED_word_array+216]: word;
  LED_word_line10[@LED_word_array+240]: word;
  LED_word_line11[@LED_word_array+264]: word;

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
  my_Byte:= ByteToBCD(my_second) and $7F; // Clock HALT Bit immer l�schen
  TWIout(rtc_adr,0,my_Byte); // Sekunden-Register
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
  my_Byte:= ByteToBCD(my_hour) and 31;
  TWIout(rtc_adr,2,my_Byte); // Stunden-Register
end;

//##############################################################################

procedure InitPorts;
begin
  PortB:= %00000111;
  DDRB:=  %00111000;
  
  PortC:= %00000000;
  DDRC:=  %00001111;

  PortD:= %00000000;
  DDRD:=  %11111111;
end InitPorts;

procedure LED_out;
begin
   PortC:=hi(LED_word) and $0F;
   PortD:=lo(LED_word);
end;

procedure LED_off;
begin
   PortC:=(PortC and $F0);
   PortD:=0;
end;


procedure LED_SR_next;
begin
  LED_off;
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
  LED_word:= LED_word_array[led_row];
  LED_out;
end;

//##############################################################################

procedure ptn2led(my_pattern: word);
var my_idx: byte;
begin
  my_idx:= hi(my_pattern) shr 4;    // Zeilennummer im obersten Nibble
  LED_word_array[my_idx]:= LED_word_array[my_idx] or my_pattern;
end;

procedure time_to_letters(my_hour, my_minute: byte; my_adjust: boolean);
var my_div, my_mod, my_addhour: byte; my_disp_uhr: Boolean;
begin
  for i:= 0 to 11 do
    LED_word_array[i]:= 0;
  endfor;

  my_disp_uhr:= false;
  my_mod:= my_minute mod 5;
// Minute words
  my_addhour:= 0;
  my_div:= my_minute div 5;

  case my_mod of // Einzel-Minuten
    0:
        ptn2led(c_es_ist);
        ptn2led(c_genau);
        |
    1,2:
        ptn2led(c_es_war);
        ptn2led(c_gerade);
        |
    3,4:
        ptn2led(c_es_ist);
        ptn2led(c_gleich);
        inc(my_div);
        if my_minute > 57 then
          my_addhour:= 1;
        endif;
        |
  endcase;

  case my_div of   // 5-Minuten-Schritte
    0,12:
        my_disp_uhr:= true;
        |
    1:
        ptn2led(c_fuenfmin);
        ptn2led(c_nach);
        |
    2:
        ptn2led(c_zehnmin);
        ptn2led(c_nach);
        |
    3:
        ptn2led(c_viertel);
        ptn2led(c_nach);
        |
    4:
        ptn2led(c_zwanzig);
        ptn2led(c_nach);
        |
    5:
        ptn2led(c_fuenfmin);
        ptn2led(c_vor);
        ptn2led(c_halb);
        my_addhour:= 1;
        |
    6:
        ptn2led(c_halb);
        my_addhour:= 1;
        |
    7:
        ptn2led(c_fuenfmin);
        ptn2led(c_nach);
        ptn2led(c_halb);
        my_addhour:= 1;
        |
    8:
        ptn2led(c_zwanzig);
        ptn2led(c_vor);
        my_addhour:= 1;
        |
    9:
        ptn2led(c_viertel);
        ptn2led(c_vor);
        my_addhour:= 1;
        |
    10:
        ptn2led(c_zehnmin);
        ptn2led(c_vor);
        my_addhour:= 1;
        |
    11:
        ptn2led(c_fuenfmin);
        ptn2led(c_vor);
        my_addhour:= 1;
        |
  endcase;
  my_hour:= my_hour + my_addhour;

  case my_hour of // Stunden-Schritte
    0,12:
      ptn2led(c_zwoelf);
      |
    1,13:
      if my_disp_uhr then
        // Sonderfall ein"s"
        ptn2led(c_ein);
      else
        ptn2led(c_eins);
      endif;
      |
    2,14:
      ptn2led(c_zwei);
      |
    3,15:
      ptn2led(c_drei);
      |
    4,16:
      ptn2led(c_vier);
      |
    5,17:
      ptn2led(c_fuenf);
      |
    6,18:
      ptn2led(c_sechs);
      |
    7,19:
      ptn2led(c_sieben);
      |
    8,20:
      ptn2led(c_acht);
      |
    9,21:
      ptn2led(c_neun);
      |
    10,22:
      ptn2led(c_zehn);
      |
    11,23:
      ptn2led(c_elf);
      |
  endcase;

  if my_disp_uhr then
    ptn2led(c_uhr);
  endif;
  if my_hour < 5 then
    ptn2led(c_nachts);
  elsif my_hour > 8 then
    if my_hour < 12 then
      ptn2led(c_vor12);
      ptn2led(c_mittag);
  elsif my_hour > 12 then
    if my_hour < 13 then
      ptn2led(c_mittag);
  elsif my_hour < 18 then
      ptn2led(c_nach12);
      ptn2led(c_mittag);
    endif;
  endif;

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
  i:= DS1307getSecond;  // First Power up, Clock HALT Bit l�schen
  DS1307setSecond(i);

  loop
    if TickSema then
      TickSema:=false;
      TESTPIN:= not TESTPIN;
      LED_SR_next;
    endif;

    if MinuteSema then
      //Blinkenlights:= true;
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
        inctolimwrap(hour,23,0);
        DS1307setHour(hour);
        DS1307setSecond(0);
        RTCsetHour(hour);
        RTCsetSecond(0);
        time_to_letters(hour, minute, true);
        LEDupdateRequest:= true;
        Blinkenlights:= false;
      endif;
      if not MINUTEBTN then // neg. Logik!
        if inctolimwrap(minute,59,0) then
          inctolimwrap(hour,23,0);
        endif;
        DS1307setHour(hour);
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
          LED_word_array[i]:= (LED_word_array[i] + random) and $FFF;
        endfor;
        if not dectolim(BlinkTimer, 0) then
          Blinkenlights:= false;
          time_to_letters(hour, minute,false);
        endif;
      endif;
    endif;

  endloop;
end wordclock.

