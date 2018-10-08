package org.eclipse.mita.base.util

import com.google.common.collect.Iterables
import com.google.common.collect.Lists
import java.util.Iterator
import java.util.List
import java.util.NoSuchElementException
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeAdapter
import org.eclipse.mita.base.typesystem.types.AbstractType

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
	def static <X> Iterable<X> init(Iterable<X> xs) {
		xs.toList.reverseView.tail.toList.reverseView;
	}
	
	def static <X> Iterable<Iterable<X>> chooseAny(Iterable<X> xs) {
		if(xs.empty) {
			return #[xs];
		}
		else {
			val x = xs.head;
			return Iterables.concat(chooseAny(xs.tail).map[Iterables.concat(#[x], it)], chooseAny(xs.tail));
		}
	}
			
	def static void main(String[] args) {

	}
	def static <T> List<T> force(Iterable<T> list) {
		return Lists.newArrayList(list);
	}
	
	def static AbstractType getType(EObject obj) {
		return TypeAdapter.get(obj.computeOrigin);
	}
	
	def static EObject computeOrigin(EObject obj) {
		val adapter = obj.eAdapters.filter(CopySourceAdapter).head;
		return if(adapter === null) {
			obj;
		} else {
			computeOrigin(adapter.getOrigin());
		}
	} 
	def static String classNameOf(int framesAbove) {
		val fullClassName = Thread.currentThread().getStackTrace().get(2 + framesAbove).className;
		val lastSegmentStartIdx = fullClassName.lastIndexOf(".") + 1;
		return fullClassName.substring(lastSegmentStartIdx).replaceAll("[a-z]", "");
	}
	def static int lineNumber() {
		return lineNumberOf(1);
	}
	def static int lineNumberOf(int framesAbove) {
		return Thread.currentThread().getStackTrace().get(2 + framesAbove).getLineNumber();
	}
}


