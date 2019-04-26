/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.util;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.Iterator;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.function.Consumer;
import java.util.function.Supplier;

import org.eclipse.emf.common.notify.Adapter;
import org.eclipse.emf.common.notify.Notification;
import org.eclipse.emf.common.notify.impl.NotificationImpl;
import org.eclipse.emf.common.util.BasicEList;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.mita.base.types.NamedElement;
import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypeKind;
import org.eclipse.mita.base.types.TypesPackage;
import org.eclipse.mita.base.types.TypesUtil;
import org.eclipse.mita.base.typesystem.infra.TypeAdapter;
import org.eclipse.mita.base.typesystem.types.AbstractType;
import org.eclipse.xtext.nodemodel.INode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;
import org.eclipse.xtext.util.OnChangeEvictingCache;
import org.eclipse.xtext.xbase.lib.CollectionLiterals;
import org.eclipse.xtext.xbase.lib.Functions.Function1;
import org.eclipse.xtext.xbase.lib.InputOutput;
import org.eclipse.xtext.xbase.lib.IterableExtensions;
import org.eclipse.xtext.xbase.lib.Pair;
import org.eclipse.xtext.xbase.lib.Procedures.Procedure0;

import com.google.common.base.Objects;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;

@SuppressWarnings("all")
public class BaseUtils {
	public static String getText(final EObject obj, final EStructuralFeature feature) {
		Object _xifexpression = null;
		boolean _contains = obj.eClass().getEAllStructuralFeatures().contains(feature);
		if (_contains) {
			_xifexpression = obj.eGet(feature, false);
		}
		final Object setProperty = _xifexpression;
		String _xifexpression_1 = null;
		if ((setProperty != null)) {
			String _xifexpression_2 = null;
			if ((setProperty instanceof TypeKind)) {
				Type _kindOf = ((TypeKind) setProperty).getKindOf();
				String _name = null;
				if (_kindOf != null) {
					_name = _kindOf.getName();
				}
				_xifexpression_2 = _name;
			} else {
				String _xifexpression_3 = null;
				if ((setProperty instanceof NamedElement)) {
					_xifexpression_3 = ((NamedElement) setProperty).getName();
				} else {
					String _xifexpression_4 = null;
					if ((setProperty instanceof EObject)) {
						List<INode> _findNodesForFeature = NodeModelUtils.findNodesForFeature(((EObject) setProperty),
								null);
						INode _head = null;
						if (_findNodesForFeature != null) {
							_head = IterableExtensions.<INode>head(_findNodesForFeature);
						}
						String _text = null;
						if (_head != null) {
							_text = _head.getText();
						}
						String _trim = null;
						if (_text != null) {
							_trim = _text.trim();
						}
						_xifexpression_4 = _trim;
					} else {
						_xifexpression_4 = setProperty.toString();
					}
					_xifexpression_3 = _xifexpression_4;
				}
				_xifexpression_2 = _xifexpression_3;
			}
			_xifexpression_1 = _xifexpression_2;
		}
		final String setPropertyName = _xifexpression_1;
		String _elvis = null;
		if (setPropertyName != null) {
			_elvis = setPropertyName;
		} else {
			List<INode> _findNodesForFeature_1 = NodeModelUtils.findNodesForFeature(BaseUtils.computeOrigin(obj),
					feature);
			INode _head_1 = null;
			if (_findNodesForFeature_1 != null) {
				_head_1 = IterableExtensions.<INode>head(_findNodesForFeature_1);
			}
			String _text_1 = null;
			if (_head_1 != null) {
				_text_1 = _head_1.getText();
			}
			String _trim_1 = null;
			if (_text_1 != null) {
				_trim_1 = _text_1.trim();
			}
			_elvis = _trim_1;
		}
		return _elvis;
	}

	public static <T extends Object> T castOrNull(final Object o, final Class<T> clazz) {
		boolean _isInstance = clazz.isInstance(o);
		if (_isInstance) {
			return clazz.cast(o);
		}
		return null;
	}

	public static <X extends Object, Y extends Object> Iterator<Pair<X, Y>> zip(final Iterator<X> xs,
			final Iterator<Y> ys) {
		return new Iterator<Pair<X, Y>>() {
			@Override
			public boolean hasNext() {
				return (xs.hasNext() && ys.hasNext());
			}

			@Override
			public Pair<X, Y> next() {
				boolean _hasNext = this.hasNext();
				boolean _not = (!_hasNext);
				if (_not) {
					throw new NoSuchElementException();
				}
				X _next = xs.next();
				Y _next_1 = ys.next();
				return Pair.<X, Y>of(_next, _next_1);
			}
		};
	}

	public static <X extends Object, Y extends Object> Iterable<Pair<X, Y>> zip(final Iterable<X> xs,
			final Iterable<Y> ys) {
		return new Iterable<Pair<X, Y>>() {
			@Override
			public Iterator<Pair<X, Y>> iterator() {
				return BaseUtils.<X, Y>zip(xs.iterator(), ys.iterator());
			}
		};
	}

	public static <X extends Object, Y extends Object> Pair<Iterator<X>, Iterator<Y>> unzip(
			final Iterator<Pair<X, Y>> xys) {
		abstract class __BaseUtils_3 implements Iterator<X> {
			Deque<X> backlogXs;

			Deque<Y> backlogYs;
		}

		abstract class __BaseUtils_4 implements Iterator<Y> {
			Deque<X> backlogXs;

			Deque<Y> backlogYs;
		}

		final Deque<X> bxs = new ArrayDeque<X>();
		final Deque<Y> bys = new ArrayDeque<Y>();
		__BaseUtils_3 ___BaseUtils_3 = new __BaseUtils_3() {
			{
				backlogXs = bxs;

				backlogYs = bys;
			}

			@Override
			public boolean hasNext() {
				return ((!this.backlogXs.isEmpty()) || xys.hasNext());
			}

			@Override
			public X next() {
				boolean _isEmpty = this.backlogXs.isEmpty();
				if (_isEmpty) {
					final Pair<X, Y> e = xys.next();
					this.backlogXs.add(e.getKey());
					this.backlogYs.add(e.getValue());
				}
				return this.backlogXs.poll();
			}
		};
		__BaseUtils_4 ___BaseUtils_4 = new __BaseUtils_4() {
			{
				backlogXs = bxs;

				backlogYs = bys;
			}

			@Override
			public boolean hasNext() {
				return ((!this.backlogYs.isEmpty()) || xys.hasNext());
			}

			@Override
			public Y next() {
				boolean _isEmpty = this.backlogYs.isEmpty();
				if (_isEmpty) {
					final Pair<X, Y> e = xys.next();
					this.backlogXs.add(e.getKey());
					this.backlogYs.add(e.getValue());
				}
				return this.backlogYs.poll();
			}
		};
		return Pair.<Iterator<X>, Iterator<Y>>of(___BaseUtils_3, ___BaseUtils_4);
	}

	public static <X extends Object, Y extends Object> Pair<Iterable<X>, Iterable<Y>> unzip(
			final Iterable<Pair<X, Y>> xys) {
		return Pair.<Iterable<X>, Iterable<Y>>of(new Iterable<X>() {
			@Override
			public Iterator<X> iterator() {
				final Function1<Pair<X, Y>, X> _function = (Pair<X, Y> it) -> {
					return it.getKey();
				};
				return IterableExtensions.<Pair<X, Y>, X>map(xys, _function).iterator();
			}
		}, new Iterable<Y>() {
			@Override
			public Iterator<Y> iterator() {
				final Function1<Pair<X, Y>, Y> _function = (Pair<X, Y> it) -> {
					return it.getValue();
				};
				return IterableExtensions.<Pair<X, Y>, Y>map(xys, _function).iterator();
			}
		});
	}

	public static <X extends Object> Iterable<X> init(final Iterable<X> xs) {
		int _size = IterableExtensions.size(xs);
		int _minus = (_size - 1);
		return IterableExtensions.<X>take(xs, _minus);
	}

	public static <X extends Object> Iterable<Iterable<X>> chooseAny(final Iterable<X> xs) {
		boolean _isEmpty = IterableExtensions.isEmpty(xs);
		if (_isEmpty) {
			return Collections.<Iterable<X>>unmodifiableList(CollectionLiterals.<Iterable<X>>newArrayList(xs));
		} else {
			final X x = IterableExtensions.<X>head(xs);
			final Function1<Iterable<X>, Iterable<X>> _function = (Iterable<X> it) -> {
				return Iterables.<X>concat(Collections.<X>unmodifiableList(CollectionLiterals.<X>newArrayList(x)), it);
			};
			return Iterables.<Iterable<X>>concat(
					IterableExtensions.<Iterable<X>, Iterable<X>>map(
							BaseUtils.<X>chooseAny(IterableExtensions.<X>tail(xs)), _function),
					BaseUtils.<X>chooseAny(IterableExtensions.<X>tail(xs)));
		}
	}

	public static <T extends Object> Iterable<Iterable<T>> transpose(final Iterable<? extends Iterable<T>> xss) {
		Iterable<Iterable<T>> _xblockexpression = null;
		{
			boolean _isEmpty = IterableExtensions.isEmpty(IterableExtensions.head(xss));
			if (_isEmpty) {
				return Collections.<Iterable<T>>unmodifiableList(CollectionLiterals.<Iterable<T>>newArrayList());
			}
			final Function1<Iterable<T>, T> _function = (Iterable<T> it) -> {
				return IterableExtensions.<T>head(it);
			};
			Iterable<T> _map = IterableExtensions.map(xss, _function);
			final Function1<Iterable<T>, Iterable<T>> _function_1 = (Iterable<T> it) -> {
				return IterableExtensions.<T>tail(it);
			};
			Iterable<Iterable<T>> _transpose = BaseUtils.<T>transpose(IterableExtensions.map(xss, _function_1));
			_xblockexpression = Iterables.<Iterable<T>>concat(
					Collections.<Iterable<T>>unmodifiableList(CollectionLiterals.<Iterable<T>>newArrayList(_map)),
					_transpose);
		}
		return _xblockexpression;
	}

	public static void notifyChanged(final EObject obj) {
		final Resource resource = obj.eResource();
		final List<OnChangeEvictingCache.CacheAdapter> cacheAdapters = BaseUtils.getCacheAdapters(resource);
		final Consumer<OnChangeEvictingCache.CacheAdapter> _function = (OnChangeEvictingCache.CacheAdapter it) -> {
			EObject _computeOrigin = BaseUtils.computeOrigin(obj);
			NotificationImpl _notificationImpl = new NotificationImpl(Notification.ADD, _computeOrigin, obj);
			it.notifyChanged(_notificationImpl);
		};
		cacheAdapters.forEach(_function);
	}

	public static void ignoreChange(final EObject obj, final Procedure0 action) {
		BaseUtils.ignoreChange(obj.eResource(), action);
	}
	
	public static <T> T ignoreChange(final EObject obj, final Supplier<T> action) {
		return BaseUtils.ignoreChange(obj.eResource(), action);
	}
	
	public static void ignoreChange(final Resource resource, final Procedure0 action) {
		BaseUtils.ignoreChange(resource, () -> {action.apply(); return null;});
	}
	
	public static <T> T ignoreChange(final Resource resource, final Supplier<T> action) {
		final List<OnChangeEvictingCache.CacheAdapter> cacheAdapters = BaseUtils.getCacheAdapters(resource);
		final Consumer<OnChangeEvictingCache.CacheAdapter> _function = (OnChangeEvictingCache.CacheAdapter it) -> {
			it.ignoreNotifications();
		};
		cacheAdapters.forEach(_function);
		T result; 
		try {
			result = action.get();
		}
		finally {
			final Consumer<OnChangeEvictingCache.CacheAdapter> _function_1 = (OnChangeEvictingCache.CacheAdapter it) -> {
				it.listenToNotifications();
			};
			cacheAdapters.forEach(_function_1);
		}
		return result;
	}

	private static List<OnChangeEvictingCache.CacheAdapter> getCacheAdapters(final Resource resource) {
		final ArrayList<OnChangeEvictingCache.CacheAdapter> cacheAdapters = BaseUtils.<OnChangeEvictingCache.CacheAdapter>force(
				Iterables.<OnChangeEvictingCache.CacheAdapter>filter(resource.eAdapters(),
						OnChangeEvictingCache.CacheAdapter.class));
		boolean _isEmpty = cacheAdapters.isEmpty();
		if (_isEmpty) {
			final OnChangeEvictingCache.CacheAdapter adapter = new OnChangeEvictingCache().getOrCreate(resource);
			return Collections.<OnChangeEvictingCache.CacheAdapter>unmodifiableList(
					CollectionLiterals.<OnChangeEvictingCache.CacheAdapter>newArrayList(adapter));
		}
		return cacheAdapters;
	}

	public static void main(final String[] args) {
		for (final String s : Collections
				.<String>unmodifiableList(CollectionLiterals.<String>newArrayList("a.b", "a.b.c"))) {
			InputOutput.<String>println(s.replaceFirst("\\.[^\\.]+$", ""));
		}
	}

	public static <T extends Object> ArrayList<T> force(final Iterable<T> list) {
		Class<? extends Iterable> _class = list.getClass();
		boolean _equals = Objects.equal(_class, ArrayList.class);
		if (_equals) {
			return ((ArrayList<T>) list);
		}
		return Lists.<T>newArrayList(list);
	}

	public static AbstractType getType(final EObject obj) {
		return TypeAdapter.get(obj);
	}

	public static EObject computeOrigin(final EObject obj) {
		return computeOrigin(obj, true);
	}
	public static EObject computeOrigin(final EObject obj, boolean recurse) {
		if(obj == null) {
			return obj;
		}
		EList<Adapter> _eAdapters = obj.eAdapters();
		
		Iterable<CopySourceAdapter> _filter = Iterables.<CopySourceAdapter>filter(_eAdapters, CopySourceAdapter.class);

		CopySourceAdapter _head = IterableExtensions.<CopySourceAdapter>head(_filter);

		final CopySourceAdapter adapter = _head;
		EObject _xifexpression = null;
		if ((adapter == null)) {
			_xifexpression = obj;
		} else if(!recurse) {
			_xifexpression = adapter.getOrigin();
		} else {
			_xifexpression = BaseUtils.computeOrigin(adapter.getOrigin(), recurse);
		}
		return _xifexpression;
	}

	public static String classNameOf(final int framesAbove) {
		final String fullClassName = Thread.currentThread().getStackTrace()[(2 + framesAbove)].getClassName();
		int _lastIndexOf = fullClassName.lastIndexOf(".");
		final int lastSegmentStartIdx = (_lastIndexOf + 1);
		return fullClassName.substring(lastSegmentStartIdx).replaceAll("[a-z]", "");
	}

	public static int lineNumber() {
		return BaseUtils.lineNumberOf(1);
	}

	public static int lineNumberOf(final int framesAbove) {
		return framesAbove;
	}

	public static String computeQID(final NamedElement element) {
		String _name = element.getName();
		boolean _tripleEquals = (_name == null);
		if (_tripleEquals) {
			return null;
		}
		StringBuilder id = new StringBuilder();
		id.append(element.getName());
		EObject container = element.eContainer();
		if ((container != null)) {
			int _indexOf = container.eContents().indexOf(element);
			final int idx = (_indexOf + 1);
			id.append("_");
			id.append(idx);
		}
		while ((container != null)) {
			{
				boolean _contains = container.eClass().getEAllStructuralFeatures()
						.contains(TypesPackage.Literals.NAMED_ELEMENT__NAME);
				if (_contains) {
					prependNamedElementName(id, container);
				} else {
					prependContainingFeatureName(id, container);
				}
				container = container.eContainer();
			}
		}
		return id.toString();
	}

	private static void prependNamedElementName(final StringBuilder id, final EObject container) {
		Object _eGet = container.eGet(TypesPackage.Literals.NAMED_ELEMENT__NAME);
		String name = ((String) _eGet);
		if ((name != null)) {
			EStructuralFeature feature = container.eContainingFeature();
			Object elements = container.eContainer().eGet(feature);
			int index = 0;
			if ((elements instanceof BasicEList)) {
				BasicEList<?> elementList = ((BasicEList<?>) elements);
				index = elementList.indexOf(container);
				name = name + index;
			}
			id.insert(0, TypesUtil.ID_SEPARATOR);
			id.insert(0, name);
		}
	}

	private static void prependContainingFeatureName(final StringBuilder id, final EObject container) {
		EStructuralFeature feature = container.eContainingFeature();
		if ((feature != null)) {
			String name = null;
			boolean _isMany = feature.isMany();
			if (_isMany) {
				Object elements = container.eContainer().eGet(feature);
				int index = 0;
				if ((elements instanceof BasicEList)) {
					BasicEList<?> elementList = ((BasicEList<?>) elements);
					index = elementList.indexOf(container);
				}
				String _name = feature.getName();
				String _plus = (_name + Integer.valueOf(index));
				name = _plus;
			} else {
				name = feature.getName();
			}
			id.insert(0, TypesUtil.ID_SEPARATOR);
			id.insert(0, name);
		}
	}
}
