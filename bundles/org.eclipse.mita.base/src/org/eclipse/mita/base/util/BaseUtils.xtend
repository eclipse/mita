package org.eclipse.mita.base.util

import java.util.Iterator
import java.util.NoSuchElementException

class BaseUtils {	
	def static <X, Y> Iterator<Pair<X, Y>> zip(Iterator<X> xs, Iterator<Y> ys) {
		new Iterator<Pair<X, Y>>() {
			override hasNext() {
				xs.hasNext() && ys.hasNext();
			}
			
			override next() {
				if(!hasNext()) {
					throw new NoSuchElementException();
				}
				return (xs.next() -> ys.next());
			}
			
		}
	}
	def static <X, Y> Iterable<Pair<X, Y>> zip(Iterable<X> xs, Iterable<Y> ys) {
		new Iterable<Pair<X, Y>>() {
			override iterator() {
				return zip(xs.iterator, ys.iterator);
			}			
		}
	}
	
	def static <T> T castOrNull(Object o, Class<T> clazz) {
		if(clazz.isInstance(o)) {
			return clazz.cast(o);
		}
		return null;
	}
}