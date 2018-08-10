package org.eclipse.mita.base.util

import com.google.common.base.Optional
import com.google.common.collect.Iterables
import com.google.common.collect.Lists
import java.util.Iterator
import java.util.List
import java.util.NoSuchElementException
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.MitaResourceSet
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
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
		val rs = obj.eResource?.resourceSet;
		if(rs instanceof MitaResourceSet) {
			return rs.latestSolution?.solution?.apply(TypeVariableAdapter.get(obj));	
		}
		return null;
	}
}


