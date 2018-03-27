---
title: "Functions"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 30
draft: false
toc: true
menu:
  main:
    parent: Language
    identifier: functions
    weight: 30
---

Functions play an important role in Mita.
They give the language a modern feel through features that go beyond what C has to offer, such as [polymorphism](#polymorphism) and [extension methods](#extension-methods).

You have already seen the `fn` keyword, which allows you to declare new functions. Alternatively you can use `function` instead of `fn` if that suits your style better.
By convention in Mita functions are named in `camel case` style. In `camel case`, words are separated by capital letters and for functions we start with a lower-case one.
Here is an example that contains function definitions:
```TypeScript
fn helloWorld() {
	return "hello world";
}

function addOne(x : int32) : int32 {
	return x + 1;
}
``` 

## Return Values
All functions have a return type. If a function does not return any value, its type is `void`.
If you don't explicitly specify a return type, the compiler will infer the common type of all `return` statements.

```TypeScript
// The compiler will infer bool as return type 
fn isEvent(x : int32) {
	if(x % 2 == 0) {
		return true;
	} else {
		return false;
	}
}

fn giveAnotherOne() : uint32 {
    return 1;
}
```

## Polymorphism
Functions can share the same name as long as the types of their parameters differ. 
This concept is referred to as `polymorphism` and is useful to enable different behavior depending on the type of input.
Suppose you wanted to serialize structures to JSON messages. Because of polymorphism you can write the following code:
```TypeScript
package main;
import platforms.xdk110;

struct AccelData {
	var x : int32;
	var y : int32;
}
struct EnvData {
	var temp : int32;
}

fn toJSON(data : AccelData) {
	return `{ "x": ${data.x}, "y": ${data.y} }`;
}
fn toJSON(data : EnvData) {
	return `{ "temp": ${data.temp} }`;
}

every 1 second {
	let environmentalState = EnvData(temp = environment.temperature.read());
	println(toJSON(environmentalState));
}
```  

Notice how we have two functions called `toJSON`. Depending on the type of the parameter they are called with, the compiler chooses
one or the other function.

## Extension Methods
In the example above we called the `toJSON` function how you would expect a function call to look like: `toJSON(environmentalState)`.
Mita offers another style of calling functions which we refer to as _extension methods_: `environmentalState.toJSON()`.
With this style you can write the first argument of the function on the left side and call the function "on that expression".
This gives the expression an object oriented look and feel, even though it is still just a plain old function call.

Extension methods are very powerful when they are combined with polymorphism.
Considering the example above we could write code that looks very object oriented, but without incurring its complexity:
```TypeScript
fn printState(accel : AccelData, env : EnvData) {
	println(accel.toJSON());
	println(env.toJSON());
}
``` 

Calling functions this way is not unique to Mita.
_Go_ supports a very similar concept (receivers), _C#_ supports an extension method concept and _Xtend_ even has the exact same concept.

## Named Parameters
When invoking functions the parameters can be specified by position or name. The style of invocation must not be mixed. There are no optional parameters.
```TypeScript
foo(1, 2);
foo(x=1, y=2);
foo(x=1, x=2); /* compile error: parameter x has already been specified */
foo(x=1, 2); /* compile error: mixed positional and named parameters */
foo(1, y=2); /* compile error: mixed positional and named parameters */
```
