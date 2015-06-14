### Readme for the DOS Toys, Demos and Whatnot project directory

## ASKPSWD.ASM 

Extremely simple password prompt demo. It should not be used **_AS-IS_**. 
Since, it uses the command line to provide the username an password. 
Does not provide a hashing function. These are only a few of the 
reasons it is not secure and should not be used in a production 
environment. 

However, it does demonstrate several things that would be required for 
a secure password prompt. Things like maximum incorrect password tries,
invalid password delays, inactivity time out, fixed time password 
comparison, sensitive data wiping before exit and more.

## MORSE.ASM

Simple toy that plays a message in morse code. The message provided at the 
command line and it uses the internal PC Speaker to generate the tones.