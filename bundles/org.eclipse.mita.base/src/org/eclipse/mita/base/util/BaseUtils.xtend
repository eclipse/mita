package org.eclipse.mita.base.util

import com.google.common.collect.Iterables
import com.google.common.collect.Lists
import java.util.ArrayDeque
import java.util.ArrayList
import java.util.Deque
import java.util.Iterator
import java.util.NoSuchElementException
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.TypeAdapter
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.util.OnChangeEvictingCache

class BaseUtils {
	def static getText(EObject obj, EStructuralFeature feature) {
		return NodeModelUtils.findNodesForFeature(obj, feature).head?.text?.trim;
	}
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
	def static <X, Y> Pair<Iterator<X>, Iterator<Y>> unzip(Iterator<Pair<X, Y>> xys) {
		val Deque<X> bxs = new ArrayDeque();
		val Deque<Y> bys = new ArrayDeque();
		return
			new Iterator<X>() {
				val backlogXs = bxs;
				val backlogYs = bys;
				override hasNext() {
					return !backlogXs.empty || xys.hasNext();
				}
				
				override next() {
					if(backlogXs.empty) {
						val e = xys.next();
						backlogXs.add(e.key);
						backlogYs.add(e.value);
					}
					return backlogXs.poll();
				}
				
			} 
		-> 
			new Iterator<Y>() {
				val backlogXs = bxs;
				val backlogYs = bys;
				override hasNext() {
					return !backlogYs.empty || xys.hasNext();
				}
				
				override next() {
					if(backlogYs.empty) {
						val e = xys.next();
						backlogXs.add(e.key);
						backlogYs.add(e.value);
					}
					return backlogYs.poll();
				}
			}
	}
	def static <X, Y> Pair<Iterable<X>, Iterable<Y>> unzip(Iterable<Pair<X, Y>> xys) {
		return 
			new Iterable<X>() {
				override iterator() {
					xys.map[it.key].iterator
				}
			}
		->
			new Iterable<Y>() {
				override iterator() {
					xys.map[it.value].iterator
				}
			} 
	}
	
	def static <X> Iterable<X> init(Iterable<X> xs) {
		xs.take(xs.size - 1);
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
	
	
	def static <T> Iterable<Iterable<T>> transpose(Iterable<? extends Iterable<T>> xss) {
		if(xss.head.empty) {
			return #[];
		}
		#[xss.map[it.head]] + transpose(xss.map[it.tail]);
	}
		
	def static void ignoreChange(EObject obj, () => void action) {
		ignoreChange(obj.eResource, action);
	}
	def static void ignoreChange(Resource resource, () => void action) {
		val cacheAdapters = getCacheAdapters(resource);
		cacheAdapters.forEach[
			it.ignoreNotifications();
		]
		action.apply()
		cacheAdapters.forEach[
			it.listenToNotifications();
		]
	}
	private def static getCacheAdapters(Resource resource) {
		val cacheAdapters = resource.eAdapters.filter(OnChangeEvictingCache.CacheAdapter).force;
		if(cacheAdapters.empty) {
			val adapter = new OnChangeEvictingCache().getOrCreate(resource);
			return #[adapter];
		}
		return cacheAdapters;
	} 
			
	def static void main(String[] args) {
		println(transpose(#[#[1,2,3], #[4,5,6]]));
	}
	def static <T> ArrayList<T> force(Iterable<T> list) {
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
		return framesAbove;
		//return Thread.currentThread().getStackTrace().get(2 + framesAbove).getLineNumber();
	}
}



