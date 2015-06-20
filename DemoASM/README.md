## DemoASM - Demos and Examples

### ASKPSWD.ASM 

Extremely simple password prompt demo. It should not be used AS-IS. Since, 
it uses the command line to provide the username an password. Does not 
provide a hashing function. These are only a few of the reasons it is 
not secure and should not be used in a production environment.

However, it does demonstrate several things that would be required 
for a secure password prompt. Things like maximum incorrect password 
tries, invalid password delays, inactivity time out, fixed time password 
comparison, sensitive data wiping before exit and more.