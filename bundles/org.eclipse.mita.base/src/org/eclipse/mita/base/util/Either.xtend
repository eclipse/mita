package org.eclipse.mita.base.util

import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

/* Either<LEFT, RIGHT> is the opposite of a Pair<A, B>. Let's compare them:
 * val Pair<Integer, Boolean> pair = new Pair<>(1, true);
 * val Either<Integer, Boolean> intLeft = new Left<>(1);
 * val Either<Integer, Boolean> boolRight = new Right<>(true);
 * 
 * now pair holds both 1 and true, where values of type Either<> hold only one of them.
 * therefore one can look at pair as a much safer version of "Object", 
 * since there are only two possible values that it may be instead of all classes on the classpath.
 * 
 * If this class is used more extensively we should add more functions like 
 * - isLeft/isRight, 
 * - map(Either<A,B>, A=>C, B=>D), 
 * - match(onLeft: A=>C, onRight: B=>C), and so on. 
 * For now instanceof is enough, since we use this only in TypeVariable.modifyNames.
 */
abstract class Either<LEFT, RIGHT> {
	public static def <LEFT, RIGHT> Either<LEFT, RIGHT> left(LEFT l) {
		return new Left(l);
	}

	public static def <LEFT, RIGHT> Either<LEFT, RIGHT> right(RIGHT r) {
		return new Right(r);
	}
}

@FinalFieldsConstructor
class Left<T, R> extends Either<T, R> {
	public val T value;
}

@FinalFieldsConstructor
class Right<T, R> extends Either<T, R> {
	public val R value;
}
