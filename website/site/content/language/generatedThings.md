---
title: "Generated Types and Functions"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 100
draft: false
toc: false
type: index
menu:
  main:
    parent: Language
    identifier: generatedThings
    weight: 100
---

## Introduction

Mita compiles to C with static memory management without large state machines or spaghetti code (unless you write that yourself). This is great for understanding how Mita code executes and runtime behaviour, however it imposes some serious limitations on what you can reasonably express in the language itself. 

To extend this there are generated types and functions. They can be used by users very easily and are more flexible than core types and functions, but need to be compiled by a small compiler fragment or generator. However they support [parametric polymorphism](https://en.wikipedia.org/wiki/Parametric_polymorphism) and types with a dynamic size, like arrays and strings.

### Generated Types

Generated types are declared like this:

```typescript
export generated type array<T, Size is uint32>
	generator "org.eclipse.mita.library.stdlib.ArrayGenerator"
	size-inferrer "org.eclipse.mita.library.stdlib.ArraySizeInferrer"
	
	constructor con();
```

Lets go through this line by line.
- `export` means this type is visible outside the package its declared in. This is optional.
- `generated type` is the keyword the parser uses to identify that you are declaring a generated type.
- `array<T, Size is uint32>` is the name of this parametric type, along with its parameters. There are two kinds of parameters:
	- Normal ones, `T`, are just a placeholder for specific instances, for example in `optional<uint32>`.
	- Size parameters, `Size is uint32`, are placeholders for actual sizes that are checked and inferred at compile time. 
- `generator "<java class>"` specifies the Java class name of your generator generating this type.
- `size-inferrer "<java class>"` specifies the Java class name of the size inferrer of this type. In most cases you can just specialize `org.eclipse.mita.library.stdlib.GenericContainerSizeInferrer` for a default sensible behaviour.
- Generated types may specify a validator that gets called per file with `validator "<java class>"`.
- `constructor con()` declares that users can write `new array<uint32, 10>()`. `con` is a generated function and may have parameters. If you want to handle this in a special way you can specify a generator, size inferrer and validator, otherwise calls to `new` are translated by the empty statement and won't be part of initializations.

#### Type Generators

Type generators are responsible for generating C code that implements all operations on types. These are:
- generating type declarations and definitions for `MitaGeneratedTypes.h`
- declaring a variable
- copying from right to left
- allocating memory for `n` instances, and assigning those instances to a C array
- copying `n` instances between C arrays

We will go over these roughly, for comprehensive examples its always best to look at the standard library.

In C there are two different kinds of type statements: declarations and definitions. Declarations sufficient to let the C compiler know that a type exists and is a structure, at that point pointers to those types can be compiled. Definitions further provide size, names and layouting to the compiler.

Both of these go into `MitaGeneratedTypes.h`, but by separating them you can declare recursive data structures.

#### Type Size Inferrers

Most types will just want to extend `org.eclipse.mita.library.stdlib.GenericContainerSizeInferrer`. It handles normal statements/expressions correctly, and you just need to specify which type parameters are data and which are size parameters. Indices for these start at one, so for example the `ArraySizeInferrer` specifies that 1: data and 2: size.
You can then extend this size inferrer for special expressions, but you probably won't need to.

### Generated Functions

#### Function Generators

#### Function Size Inferrers
