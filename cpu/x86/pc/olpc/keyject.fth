purpose: Inject additional keys into manufacturing data
\ See license at end of file

\ Search for !!! for things that may need to change for different deployments

\ See HowItWorks near end of file for a description of the overall procedure

\ !!! Re-implement this for each different deployment
: wrong-sku?  ( -- flag )
   " P#" find-tag 0=  if  true exit  then              ( pn$ )

   -null                                               ( pn$' )
   2dup " 1CL11ZP0KD6" $=  if  2drop false exit  then  ( pn$ ) \ UY BYD LiFePO4
   2dup " 1CL11ZP0KD7" $=  if  2drop false exit  then  ( pn$ ) \ UY GP NiMH
   2dup " 1CL11ZP0KD9" $=  if  2drop false exit  then  ( pn$ ) \ UY GP LiFePO4
[ifdef] test-me
   2dup " 1CL11ZU0KDB" $=  if  2drop false exit  then  ( pn$ ) \ US for testing
[then]
   2drop

   true
;

\ !!! Change the date for each different deployment
: keyject-expired?  ( -- flag )  " 20131108T000000Z" expired?  ;

\ !!! Change the key list for each different deployment
: new-key-list$  ( -- )  " o1 s1 d1 w1 a1"  ;

\ True if the requested tags are all present and all correct.
\ This prevents endless looping.
0 value already-injected

: key-differs  ( name$ -- )
   ." Key " type ."  did differ." cr
   false to already-injected
;

: key-missing  ( name$ -- )
   ." Key " type ."  was missing." cr
   false to already-injected
;

: key-unknown  ( name$ -- )
   ." Key " type ."  is unknown, no dropin." cr
   \ no action possible, needs keyjector to be recreated.
;

: key-ok  ( name$ -- )
   ." Key " type ."  is okay." cr
   \ no action desired.
;

: test-key  ( name$ -- )
   2dup find-tag  if                    ( name$ value$ )
      2over find-drop-in  if            ( name$ value$ existing$ )
         $=  0=  if                     ( name$ )
            2dup key-differs            ( name$ )
         else
            2dup key-ok
         then                           ( name$ )
      else                              ( name$ value$ )
         2drop 2dup key-unknown         ( name$ )
      then                              ( name$ )
      2drop                             ( )
   else                                 ( name$ )
      key-missing                       ( )
   then                                 ( )
;

: already-injected?  ( -- flag )
   true to already-injected             ( )
   new-key-list$  begin  dup  while     ( $ )
      bl left-parse-string              ( $' name$ )
      test-key                          ( $ )
   repeat                               ( $ )
   2drop                                ( )
   already-injected                     ( flag )
;

: inject-key  ( name$ -- )
   2dup find-drop-in  if                        ( name$ value$ )
      green-letters                             ( name$ value$ )
      2over ram-find-tag  if                    ( name$ value$ oldvalue$ )
         2 pick <>  if                          ( name$ value$ oldvalue-adr )
            drop                                ( name$ value$ )
            2over ($delete-tag)                 ( name$ value$ )
            2over ." Deleted " type cr          ( name$ value$ )
            2over 2over 2swap ($add-tag)        ( name$ value$ )
            2swap ." Added " type cr            ( value$ )
         else                                   ( name$ value$ oldvalue-adr )
            >r 2tuck  r> swap  move             ( value$ name$ )
            ." Replaced " type cr               ( value$ )
         then                                   ( value$ )
      else                                      ( name$ value$ )
         2swap                                  ( value$ name$ )
         2over 2over ($add-tag)                 ( value$ name$ )
         ." Added " type cr                     ( value$ )
      then                                      ( value$ )
      cancel                                    ( value$ )
      free-mem                                  ( )
   else                                         ( name$ )
      ." Warning: key " type ."  is not in firmware image dropins" cr  ( )
   then                                         ( )
;

: inject-keys  ( -- )
   get-mfg-data
   new-key-list$  begin  dup  while  ( $ )
      bl left-parse-string           ( $' name$ )
      inject-key                     ( $ )
   repeat                            ( $ )
   2drop                             ( )
   (put-mfg-data)                    ( )
;

: keyject-error  ( msg$ -- )
   cr
   red-letters  ." Not injecting because:   "  type  cr  cancel
   cr
   ." Will update firmware in 20 seconds" cr
   d# 21 1 do i .d (cr d# 1,000 ms loop
;

: do-keyject?  ( -- flag )
   wrong-sku?  if
      " Wrong SKU" keyject-error
      false exit
   then
   keyject-expired?  if
      " Date Expired" keyject-error
      false exit
   then
   already-injected?   if
      " Keys Already Present" keyject-error
      false exit
   then
   true
;

false value new-firmware?
: got-firmware?  ( dev$ -- flag )
   2dup ." Looking for new fw.zip on " type cr     ( dev$ )
   dn-buf place                                         ( )
   " \boot" pn-buf place                                ( )
   filesystem-present?  0=  if  false exit  then        ( )
   null$ cn-buf place                                   ( )
   " fw" bundle-present?  0=  if  false exit  then ( )
   ."   Found" cr                                       ( )
   secure?  if                                          ( )
      load-crypto  if                                   ( )
         ." Crypto load failed" cr  false exit          ( )
      then                                              ( )
      fwkey$ to pubkey$                                 ( )
      img$ sig$ fw-valid?  0=  if                       ( )
         ."   Bad signature" cr                         ( )
         false exit
      then                                              ( )
   then                                                 ( )
   img$ tuck  flash-buf swap /flash min  move           ( len )
   ['] ?image-valid catch  if                           ( x )
      ."   Bad firmware image" cr                       ( x )
      drop false exit
   then                                                 ( )
   ."   Good image" cr                                  ( )

   true to new-firmware?                                ( )
   true                                                 ( true )
;

: get-new-firmware  ( -- )
   all-devices$  begin  dup  while         ( $ )
      bl left-parse-string                 ( $' dev$ )
      got-firmware?  if  2drop exit  then  ( $ )
   repeat                                  ( $ )
   2drop
;

: ac-connected?  ( -- flag )  bat-status@ h# 10 and  0<>  ;

\ Empirically, a weak-but-present battery can present the "trickle charge" (80)
\ but not present the "present" bit (01).
: battery-present?  ( -- flag )  bat-status@ h# 81 and  0<>  ;

\ Similarly, a weak-but-present battery can present the "trickle charge" (80)
\ but not present the "battery low" bit (04).
: battery-strong?  ( -- flag )  bat-status@ h# 84 and  0=  ;

: wait-enough-power  ( -- )
   ac-connected?  0=  if
      ." Please connect the AC adapter to continue..."
      begin  d# 100 ms  ac-connected?  until
      cr
   then
   battery-present?  0=  if
      ." Please insert a well-charged battery to continue..."
      begin  d# 100 ms  battery-present?  until
      cr
   then
   battery-strong?  0=  if
      ." The battery is low.  Please insert a charged one to continue..."
      begin  d# 100 ms  battery-present? battery-strong? and  until
   then
;

\ Firmware is in flash-buf
: update-firmware  ( -- )
   write-firmware

   ['] verify-firmware catch  if
      ." Verify failed.  Retrying once"  cr
      spi-identify
      write-firmware
      verify-firmware
   then
;

: ?keyject  ( -- )
   visible
   green-letters  cr ." Security Key Injector" cr cr  cancel
   \ Get the new firmware first, so any security checks use the old keys
   get-new-firmware
   do-keyject?  if
      wait-enough-power
      flash-write-enable
      inject-keys
      new-firmware?  if  update-firmware  then
      flash-write-disable  \ Should reboot
   else
      \ If we can't update the firmware, don't touch the SPI FLASH, lest
      \ we get into an infinite reboot cycle.
      new-firmware?  if
         ." Updating firmware ..." cr
         wait-enough-power
         flash-write-enable
         update-firmware
         flash-write-disable  \ Should reboot
      then
   then
;

?keyject

[ifdef] HowItWorks
OLPC signs bootfw.zip containing OFW image A and fw.zip containing OFW image B.
* A is an OFW with additional keyjector functionality
* B is an ordinary OFW
Version number B > version number A.

bootfw.zip and fw.zip are presented to a deployment machine in the usual manner,
either on a USB key or as part of a signed OS image.

On a deployment machine with firmware X (version X < version A):

The deployment machine (with old firmware version X < A)
auto-reflashes itself with firmware A via the existing secure
reflash mechanism.

1) Firmware A starts and chacks that:
  + The SKU is for the intended deployment
  + the date is before the keyjector expiration date
  + The override keys are not already present
so it
  ! Injects the new keys
then it
  ! Reads fw.zip, checks its signature, and reflashes with firmware B (version > A)
  ! Reboots

2) Firmware B starts, performs the normal fw update attempt step,
noticing that data.img (firmware A) is downrev, and proceeds to
boot normally.

In step (1), on a non-UY SKU, or after the expiration date,
firmware A skips the keyjection step and instead goes straight
to the "reflash firmware B" step.

In either case, the machine ends up with (normal) firmware B.
[then]

\ LICENSE_BEGIN
\ Copyright (c) 2007 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
