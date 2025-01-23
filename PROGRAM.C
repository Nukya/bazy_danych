#include <stdio.h>
#include "crster.h"
#include "robolib.h"
#include <math.h>

int bok=0;
int i=0;
int j=1;
int x=0;
int y=0;
int z=0;
int kat60=20;
int orient=0;
int nam =0;

int main()
{
progstart();

go2mfast(2);
bok = odleglosc(1);
printf("bok to %d\n",bok);


obr2marker(1);
obrotokat(19);
orient = orientacja();

koszenie(1);
while(odleglosc(1)>=bok){ 
	jazda(naped(2, 2));
	czekaj(9);
	}
	stopuj();

for(j=1; j<=5; j++)
{
	printf("j = %d\n",j);
	jazda(naped(2, 2));
	czekaj(9);
	stopuj();
	while(odleglosc(1)<bok){ 
 		korjazdy(0, orient, 20, 34);
		jazda(naped(2, 2)); 
		czekaj(9);
		stopuj();
		printf("odleglosc od markera 1 %d\n",odleglosc(1));
		printf("orientacja =  %d\n",orient);
	}

	obrotokat(-20);
	orient = orientacja();
}

go2mfast(2);

progstop();

}