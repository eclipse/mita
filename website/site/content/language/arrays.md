---
title: "Arrays"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 25
draft: false
toc: false
type: index
menu:
  main:
    parent: Language
    identifier: arrays
    weight: 25
---


Arrays are a fixed-size sequence of objects. In Mita, arrays can hold any type:

```TypeScript
var array1 : array<int32>;

struct vec2d {
    var x : int32;
    var y : int32;
}
let array2 : array<vec2d>;
```

## Initialization

There are multiple ways to initialize and fill arrays:

```TypeScript
let array1 : array<int32> = new array<int32>(size = 10);
let array2 : array<int32> = [1,2,3,4];
```

## Length

Mita arrays know how long arrays are, unlike C arrays. This allows you to do a lot of things with arrays without knowing their size. 

```TypeScript
fn sum(a : array<int32>) {
    var result = 0;
    for(var i = 0; i < a.length(); i++) {
      result += a[i];
    }
    return result;
}
```

The only exception to that is returning arrays. While we try hard to do [element size inference]({{< ref "concepts/index.md#element-size-inference" >}}), in some cases we fail to correctly infer the size of your array and inform you about it. In that case you need to manually specify the array length:

```TypeScript
fn returnsArray(): array<int32> {
  let array1 = new array<int32>(size = 10);
  return array1;
}
```

## Access

You access arrays using the familiar square brackets `[]`:

```TypeScript
let array1 = [1,2,3,4,5];
let v1 = array1[1];
array1[2] = v1;
```

## Slices

{{< warning title="Copy by value" >}}
Everything is copy by value!
{{< /warning >}}

If you only need to take some parts of your array, you can use slices. A slice of an array is a __copy__ of part of the array. For example, in the following code, `array2` contains the values `[2, 3]`:

```TypeScript
let array1 = [1,2,3,4,5];
let array2 = array1[1:3];
```

You can leave out the upper or lower bound of the slice, or both.

## Bounds checks

Whenever you access parts of an array, be it by direct access or slices, we need to do a bounds check. In many cases this doesn't impart any runtime impact, since we can infer the bounds statically. If we can't, we generate bounds checks and throw an `IndexOutOfBoundsException` on failure. See [Exceptions]({{< ref "language/exceptions.md" >}}) for more info.