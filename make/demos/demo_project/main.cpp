#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include "gcd.h"
 
int main()
{
	int a, b;
	std::cin >> a >> b;
	std::cout << gcd(a, b) << std::endl;
}
