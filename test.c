#include <stdio.h>
#define eM(x) *p*x;
#define eL(x) *(p+x)+=
#define eK(x) *p*x;
#define eJ(x) *(p-x)+=
#define eI(x) *p=x;
#define eH(x) }
#define eG(x) while(*p){
#define eF(x) p+=x;
#define eE(x) p-=x;
#define eD(x) putchar(*p);
#define eC(x) *p-=x;
#define eB(x) c=getchar();if(c>=0)*p=c;
#define eA(x) *p+=x;
char buf[0xffff];
int main(){
char *p=buf;
int c;
eF(1)
eA(9)
eJ(1)
eK(8)
eI(0)
eE(1)
eD(0)
eF(1)
eA(7)
eJ(1)
eK(4)
eI(0)
eE(1)
eA(1)
eD(0)
eA(7)
eD(0)
eD(0)
eA(3)
eD(0)
eF(3)
eA(8)
eJ(1)
eK(4)
eI(0)
eE(1)
eD(0)
eF(3)
eA(10)
eJ(1)
eK(9)
eI(0)
eE(1)
eC(3)
eD(0)
eE(4)
eD(0)
eA(3)
eD(0)
eC(6)
eD(0)
eC(8)
eD(0)
eF(2)
eA(1)
return 0;}
