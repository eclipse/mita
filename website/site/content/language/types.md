---
title: "Types"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 20
draft: false
toc: false
type: index
menu:
  main:
    parent: Language
    identifier: types
    weight: 20
---

## Primitive Types
We have already seen the [basic data types]({{< ref "basics.md#primitive-data-types" >}}) supported by Mita.
Primitive types are also called _scalar types_ in other languages, as they contain a single value. 
Complex types on the other hand represent more than a single value, or are defined by the programmer.
There is one type where that distinction is not as clear as it may sound: strings.

## Strings
In C there are no strings, but only arrays of characters and some conventions.
There, strings are really non-scalar values as they consist of a list of individual bytes.
You as a programmer will have to tell the compiler how much space you would like to reserve for your string.

This is not how we think of strings nowadays. 
In Mita strings are first-class citizens, meaning that they feel like strings on other languages.
You can simply initialize a variable with them, append them, pass them to a function and return them from one.
Behind the scenes we use [element size inference]({{< ref "concepts/index.md#element-size-inference" >}}) to try and compute the worst-case length of a string at compile time and allocate enough space.


```TypeScript
fn stringDemo() {
	var msg = "Hello ";
	msg += "World";
	
	println(msg);
}
```

There are cases where we cannot infer the length of a string, for example when it's modified within a loop.
In such cases you will have to explicitly tell us how long your string can be in the worst-case: 
```TypeScript
var msg = new string(100);
for(var i = 0; i < 5; i++) {
	msg += `${i} `;
}
println(msg);
```

## Enumerations
Enumerations are categorical values that we as programmers can define.
An enumeration type groups a set of such categorical values.
For example, if we wanted to describe a list of colors, we could define a color enumeration:
```TypeScript
enum Color {
    Red,
    Green,
    Blue
}
```

Compared to using integers for categorical values, enumerations provide type safety and a fixed set of values.
Unlike C, however, integers and enumerations are not interchangeable in Mita.
This is on purpose, as the loose interchangeability encourages bad coding style.

```TypeScript
Foo.Bar as uint8 /* compiler error: Types Foo and uint8_t are not compatible. */
```
	
## Structures
 Structures are custom, user-defined types for organizing data. Every structure member needs to be annotated with a type.

```TypeScript
struct Foo {
    var bar : uint32;
    var foo : bool;
    var baz; /* syntax error: Expected : not ; */
}
```

You can create structures by just calling them like a function with all of their members as parameters. Accessing structure members works the same as in other languages.

```TypeScript
struct vec2d {
    var x: int32;
    var y: int32;
}

fn incVec2d(v: vec2d) {
    var w: vec2d; /* By default, all structure members are initialized with 0 */
    var x = v.x;
    var y = v.y;
    w = vec2d(x + 1, y + 1);
    /* as with other functions, you can provide arguments by name */
    w = vec2d(x = v.x + 1,
              y = v.y + 1);
    return w;
}
```

## Sum Types

A generalization of enumerations and structures are [sum types](https://en.wikipedia.org/wiki/Algebraic_data_type). You might also know them by the name "tagged union" or "variadic type".

Lets say you want to write a function `deviceState` that tells you in which state your device is. It tells you whether it is standing still, moving or has detected a shock. Furthermore, some of these states should contain some more information:

- While moving you want to know in which directions you are accelerating
- When you detect a shock you also want to store how strong the shock was
- No further information is stored when standing still

Sum types can exactly model this kind of information. In Mita you write the following:

```TypeScript
alt DeviceState {
    NoMotion
  | Movement: {accelerationX : int32, accelerationY : int32, accelerationZ : int32}
  | Shock: uint32
}
```

This declares a type `DeviceState` with three different constructors:

- `DeviceState.NoMotion`, which takes no arguments
- `DeviceState.Movement`, which has three named arguments, one for each axis
- `DeviceState.Shock`, which has one named argument: the amplitude of the shock

So your function `deviceState` looks like this:

```TypeScript
fn deviceState() : DeviceState {
    var state : DeviceState;
    
    /* detect shock or movement */

    if(shockDetected) {
        state = DeviceState.Shock(accelerometer.magnitude.read());
    } else if(isMoving) {
        state = DeviceState.Movement(
          accelerationX = accelerometer.x_axis.read(),
          accelerationY = accelerometer.y_axis.read(),
          accelerationZ = accelerometer.z_axis.read());
    } else {
        state = DeviceState.NoMotion();
    }
    return state;
}
```

Next, you need to access information stored in a sum type somehow. For this, Mita offers a construct similar to switch-cases you might know from other languages. There are two things you can do with a sum type:

- You can find out which alternative constructor you got
- You can find out what information is stored in it

The first thing is just what enums do and looks like this:

```
var state : DeviceState = deviceState();

where(state) {
    is(DeviceState.NoMotion) {
        println("Standing still.");
    }
    is(DeviceState.Movement) {
        println("Device in motion.");
    }
    is(DeviceState.Shock) {
        println("Shock detected!");
    }
}
```

To access data that comes with an alternative (e.g. `accelerationX` in `DeviceState.Movement`), you need to bind that data to variables:

```
var state : DeviceState = deviceState();

where(state) {
    is(DeviceState.NoMotion) {
        println("Standing still.");
    } 
    is(DeviceState.Movement -> x, y, z) {
        println(`Device in motion: ${x} | ${y} | ${z}.`);
    }
    is(DeviceState.Shock -> intensity) {
        println(`Shock detected: ${intensity}!`);
    }
}
```

You can reuse existing structures directly if they are the only value in one alternative. This makes your code more reusable. For example, instead of defining `DeviceState.Movement` with three parameters, you can reuse an existing struct `vec3d_t`:

```TypeScript
struct vec3d_t {
    var x : int32;
    var y : int32;
    var z : int32;
}

alt DeviceState {
    NoMotion
  | Movement: vec3d_t
  | Shock: uint32
}
```

The code for `deviceState` changes slightly, since `vec3d_t`'s members have different names now. Constructing a `DeviceState.Movement` therefore looks like this:

```TypeScript
state = DeviceState.Movement(
    x = accelerometer.x_axis.read(),
    y = accelerometer.y_axis.read(),
    z = accelerometer.z_axis.read());
```

However you don't need to pass in a member of the struct at all; it is "imported" to 
`DeviceState.Movement`. Binding data contained in the alternative works just as before as well.

Some more things you can do are:

- You can directly bind the whole element that was matched. This is especially useful for embedded types, since you get a variable of the embedded type instead of the sum type. The syntax for this is:

```TypeScript
is(v : DeviceState.Movement) {
    /* v has type vec3d_t here */
}
```

- You can bind using named parameters, e.g. the `DeviceState.Movement` above has the named parameters `accelerationX`, `accelerationY` and `accelerationZ`. This looks like this:

```TypeScript
is(DeviceState.Movement -> 
    x = vec3d.accelerationX, 
    z = vec3d.accelerationZ, 
    y = vec3d.accelerationY) {
    /* Use a, b and c here */  
}
```

- You can supply a default case with `isother { ... }`.

Matching happens in the order you specify.

Here you can see a comprehensive example using all the available syntax:

```TypeScript
struct vec2d_t {
    var x : int32;
    var y : int32;
}

alt anyVec { 
    vec0d /* singleton, like an enumeration value */ 
  | vec1d : int32 
  | vec2d : vec2d_t /* embedded structure */
  | vec3d : {x: int32, y: int32, z: int32} /* named members */
  | vec4d : int32, int32, int32, int32 /* anonymous members */
}

exception UnknownTypeException;

fn incVecs(a: anyVec) {
    var b : anyVec;
    where(a) {
        is(anyVec.vec0d) {
            b = anyVec.vec0d(); 
        } 
        is(anyVec.vec1d -> x) {
           b = anyVec.vec1d(x + 1);
        }
        is(v: anyVec.vec2d) {
          /* v is of type vec2d_t */
          b = anyVec.vec2d(v.x + 1, v.y + 1);
        }
        is(anyVec.vec3d -> x = vec3d.x, y = vec3d.y, z = vec3d.z) {
           b = anyVec.vec3d(x + 1, y + 1, z + 1);
        }
        is(anyVec.vec4d -> x, y, z, w) {
           b = anyVec.vec4d(x + 1, y + 1, z + 1, w + 1);
        } 
        /* you can specify a default case */
        isother {
           throw UnknownTypeException;
        } 
    } 
    return b;
}
```

## Optionals

All types can be made optional using the `?` operator:
```TypeScript
let intOpt : uint32?;
struct strct {
    var x : uint32;
}
let structOpt : strct?;
```

Initializing can be done either by implicit upcasting in most cases, or by explicit construction using `some` and `none`:

```TypeScript
let x : uint32? = 1;
let y = some(2);
let z : int32? = none();
```

To check if an optional contains a value you use the function `hasValue`. If an optional has a value you can get it with the function `value`:

```TypeScript
let foo : uint32? = 42;
if(foo.hasValue()) {
    println(`foo has value ${foo.value()}`);
}
```

## References

Since all assignment semantics are copy by value you need a way to specify you want to have another reference to some object. For this you can use references. Unlike C pointers, references may never refer to nothing. To emphasize this, their type is annotated with an ampersand `&` instead of an asterix `*`:

```TypeScript
var someInt : int32 = 10;
var refToSomeInt : &int32 = &someInt;
*refToSomeInt = 1;
```

You can reference references as well. However, you need to store every intermediate reference explicitly.

```TypeScript
var someInt : int32 = 10;
var refToSomeInt : &int32 = &someInt;
var doubleRef : &&int32 = &refToSomeInt;
**doubleRef = 1;
```

Since our language is heapless, there are some restrictions on how you can modify and pass references. The compiler forbids you from using them in some way that might lead to accessing invalid memory. These rules are as follows:

- You can always read contents of references 
- You can never return references or anything that might contain references
- You can always pass references to another function
- You can always reference value types
- You can always modify values that are referenced (that is the base values that are referenced)
- You can do whatever you want to (contents of) values that you didn't get by reference 
- You can only modify your own referenced references



