---
title: "Exceptions"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 40
draft: false
toc: true
menu:
  main:
    parent: Language
    identifier: exceptions
    weight: 40
---



## Exceptions
Exceptions are special types defined by the exception keyword:

```TypeScript
exception FooException;
```

Exceptions can be thrown, which returns control flow to the caller. If the exception is not caught by the caller it propagates further. If the exception is never caught it causes a system reset.

```TypeScript
throw FooException;
```

Exceptions can be caught with the familiar `try...catch` syntax:

```TypeScript
try {
    throw FooException;
} catch(FooException) {
    println("Caught FooException");
}
```

Exceptions are implicit, meaning that functions do not have to (and cannot) declare the exceptions they might throw.

```TypeScript
fn doSomething() {
    throw FooException;
}
```

Similarly to other languages you can also have a `finally` block for cleanup:

```TypeScript
try {
    throw FooException;
} catch(FooException) {
    println("Caught FooException");
} finally {
    println("In finally");
} 
/* prints:
Caught FooException
In finally
*/
```

If you want to have a "catch all", you can catch just `Exception`, which is a kind-of "supertype" of all other exceptions:

```
TypeScript
try {
    throw FooException;
} catch(Exception) {
    println("Caught something");
}
```

You can nest `try/catch/finally` within each other freely. 