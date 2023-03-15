## Tests

Test select target
    `$ cd tests/target_select`
    `$ ./test.sh`

Test variables
    `$ cd ../variable`
    `$ ./test.sh`

Test silent
    `$ cd ../silent`
    `$ ./test.sh`

Test dependencies
    `$ cd ../dependencies`
    `$ ./test.sh`

Test multilines
    `$ cd ../multilines`
    `$ ./test.sh`

Test overriding
    `$ cd ../overriding`
    `$ ./test.sh`
```
Makefile:8: предупреждение: переопределение способа для цели «b»
Makefile:2: предупреждение: старый способ для цели «b» игнорируются
Makefile:11: предупреждение: переопределение способа для цели «a»
Makefile:5: предупреждение: старый способ для цели «a» игнорируются
Makefile:14: предупреждение: переопределение способа для цели «x»
Makefile:11: предупреждение: старый способ для цели «x» игнорируются
Makefile:8: предупреждение: переопределение способа для цели «b»
Makefile:2: предупреждение: старый способ для цели «b» игнорируются
Makefile:11: предупреждение: переопределение способа для цели «a»
Makefile:5: предупреждение: старый способ для цели «a» игнорируются
Makefile:14: предупреждение: переопределение способа для цели «x»
Makefile:11: предупреждение: старый способ для цели «x» игнорируются
Makefile:8: предупреждение: переопределение способа для цели «b»
Makefile:2: предупреждение: старый способ для цели «b» игнорируются
Makefile:11: предупреждение: переопределение способа для цели «a»
Makefile:5: предупреждение: старый способ для цели «a» игнорируются
Makefile:14: предупреждение: переопределение способа для цели «x»
Makefile:11: предупреждение: старый способ для цели «x» игнорируются
Makefile: warning: overriding recipe for target 'b'
Makefile: warning: ignoring old recipe for target 'b'
Makefile: warning: overriding recipe for target 'a'
Makefile: warning: ignoring old recipe for target 'a'
Makefile: warning: overriding recipe for target 'x'
Makefile: warning: ignoring old recipe for target 'x'
Makefile: warning: overriding recipe for target 'b'
Makefile: warning: ignoring old recipe for target 'b'
Makefile: warning: overriding recipe for target 'a'
Makefile: warning: ignoring old recipe for target 'a'
Makefile: warning: overriding recipe for target 'x'
Makefile: warning: ignoring old recipe for target 'x'
Makefile: warning: overriding recipe for target 'b'
Makefile: warning: ignoring old recipe for target 'b'
Makefile: warning: overriding recipe for target 'a'
Makefile: warning: ignoring old recipe for target 'a'
Makefile: warning: overriding recipe for target 'x'
Makefile: warning: ignoring old recipe for target 'x'
```

Test circular
    `$ cd ../circular`
    `$ ./test.sh`
```
make: Циклическая зависимость b <- a пропущена.
make: Циклическая зависимость a <- b пропущена.
make: Circular b <- a dependency dropped.
make: Circular a <- b dependency dropped.
```

Test errors
    `$ cd ../errors`
    `$ ./test.sh`
```
make: *** Нет правила для сборки цели «no».  Останов.
make: *** No rule to make target `no`. Stop.
----
make: *** Нет правила для сборки цели «no», требуемой для «no_rule».  Останов.
No rule to make target `no`, needed by `no_rule`.
----
cat: fds: Нет такого файла или каталога
make: *** [Makefile:5: rule_error] Error 1
cat: fds: Нет такого файла или каталога
make: *** [Makefile: rule_error] Error 1
----
3,4c3,4
< make: «upToDate» не требует обновления.
< make: Цель «is_up_to_date» не требует выполнения команд.
---
> make: `upToDate` is up to date.
> make: Nothing to be done for `is_up_to_date`.
6,7c6,7
< make: Цель «is_up_to_date» не требует выполнения команд.
< make: Цель «nothing_to_do» не требует выполнения команд.
---
> make: Nothing to be done for `is_up_to_date`.
> make: Nothing to be done for `nothing_to_do`.
```

Test timestamp
    `$ cd ../timestat`
    `$ ./test.sh`
```
3c3
< make: «t3s» не требует обновления.
---
> make: `t3s` is up to date.
```