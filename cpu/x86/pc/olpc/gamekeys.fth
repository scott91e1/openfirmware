purpose: Access to game keys (buttons on front panel)

0 value game-key-mask

: show-key  ( mask x y -- )
   at-xy game-key-mask and if  ." *" else  ." ."  then
;
: update-game-keys  ( mask -- )
   dup game-key-mask or  to game-key-mask
   rocker-up      2 2 show-key
   rocker-left    0 3 show-key
   rocker-right   4 3 show-key
   rocker-down    2 4 show-key
   button-rotate  2 6 show-key

   button-o       9 2 show-key
   button-square  7 3 show-key
   button-check   d# 11 3 show-key
   button-x       9 4 show-key
   drop
;

: read-game-keys  ( -- )
   board-revision h# b18 <  if
      button-x to game-key-mask  \ Force slow boot
      exit
   then

   game-key@  dup to game-key-mask  if
      ." Release the game keys to continue" cr
      begin  d# 100 ms  game-key@ dup update-game-keys 0=  until
      0 7 at-xy
   then
;
: game-key?  ( mask -- flag )  game-key-mask and 0<>  ;

: (hold-message)  ( ms -- )
[ifdef] test-station
   test-station  if  drop exit  then
[then]
   d# 100 /            ( decisecs )
   begin  dup  while   ( decisecs )
      dup d# 10 /mod  swap  if  drop  else  (cr .d  then   ( decisecs )
      d# 100 ms        ( decisecs )
      1-               ( decisecs )
      button-rotate game-key@ and  if  ( decisecs )
         (cr ." Release the game button to continue"
         begin  button-rotate game-key@ and  while  d# 100 ms  repeat
         (cr kill-line
         drop exit
      then
   repeat
   drop  (cr kill-line
;
' (hold-message) to hold-message

: bypass-bios-boot?  ( -- flag )  button-square game-key?  ;

: check-keys
   clear-screen
   ." Press a key to exit"
   cursor-off
   begin
      0 to game-key-mask  
      d# 100 ms key? game-key@ update-game-keys       ( key? ) 
   until
   0 7 at-xy
   cursor-on
;
