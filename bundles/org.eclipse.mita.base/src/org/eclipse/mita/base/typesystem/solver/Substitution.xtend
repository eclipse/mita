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

package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import it.unimi.dsi.fastutil.ints.Int2ObjectMap
import it.unimi.dsi.fastutil.ints.Int2ObjectMaps
import it.unimi.dsi.fastutil.ints.Int2ObjectOpenHashMap
import it.unimi.dsi.fastutil.ints.IntOpenHashSet
import it.unimi.dsi.fastutil.ints.IntSet
import java.util.Map
import java.util.function.Predicate
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.DebugTimer
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy

class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	@Accessors
	protected Int2ObjectMap<AbstractType> content = new Int2ObjectOpenHashMap();
	protected Int2ObjectMap<TypeVariable> idxToTypeVariable = new Int2ObjectOpenHashMap();
	protected Int2ObjectMap<IntSet> tvHasThisFreeVar = new Int2ObjectOpenHashMap();
	
	def Substitution filter(Predicate<TypeVariable> predicate) {
		val result = new Substitution;
		result.constraintSystemProvider = constraintSystemProvider;
		
		result.content.putAll(content.filter[idx, __| predicate.test(idxToTypeVariable.get(idx.intValue)) ])
		result.idxToTypeVariable.putAll(idxToTypeVariable.filter[idx, __| predicate.test(idxToTypeVariable.get(idx.intValue)) ])
		
		return result;
	}
	
	protected def checkDuplicate(TypeVariable key, Provider<AbstractType> type) {
		val prevType = content.get(key.idx);
		if(prevType !== null) {
			val newType = type.get;
			if(prevType != newType) {
				print("")
			}

			println('''overriding «key» ≔ «prevType» with «newType»''')
		}
	}
	
	def void add(TypeVariable variable, AbstractType type) {
		if(variable === null || type === null) {
			throw new NullPointerException;
		}
		add(#[variable->type]);
	}
	
	def void add(Map<TypeVariable, AbstractType> content) {
		val newContent = new Substitution();
		content.forEach[tv, typ|
			newContent.addToContent(tv, typ);
		]
		newContent.applyMutating(this);
	}
	def void add(Iterable<Pair<TypeVariable, AbstractType>> content) {
		add(content.toMap([it.key], [it.value]))
	}
	
	def Substitution replace(TypeVariable from, AbstractType with) {
		val result = new Substitution();
		result.constraintSystemProvider = constraintSystemProvider;
		result.content = new Int2ObjectOpenHashMap(content.mapValues[it.replace(from, with)])
		// nothing changes for typevariable idx
		result.idxToTypeVariable = new Int2ObjectOpenHashMap(idxToTypeVariable);
		return result;
	}
	def Substitution replaceMutating(TypeVariable from, AbstractType with) {
		val result = this;
		for(int k: result.content.keySet.force) {
			val vOld = result.content.get(k);
			val vNew = vOld.replace(from, with);
			if(vOld !== vNew) {	
				result.content.put(k, vNew);	
			}
		}
		// nothing changes for typevariable idx
		return result;
	}
	
	def AbstractType apply(TypeVariable typeVar) {
		var AbstractType result = typeVar;
		var nextResult = content.get(typeVar.idx); 
		while(nextResult !== null && result != nextResult && !result.freeVars.empty) {
			result = nextResult;
			nextResult = applyToType(result);
		}
		return result;
	}
	
	def Substitution apply(Substitution oldEntries) {
		return new Substitution(this).applyMutating(oldEntries);
	}
	
	// returns the mutated argument (or a copy of this if other is an empty substitution)
	def Substitution applyMutating(Substitution oldEntries) {
		if(oldEntries == EMPTY) {
			return new Substitution(this);
		}
		val copyOld = new Substitution(oldEntries);
		val copyNew = new Substitution(this);
		val result = oldEntries;
		val newEntries = this;
		result.constraintSystemProvider = newEntries.constraintSystemProvider ?: oldEntries.constraintSystemProvider;
		result.idxToTypeVariable.putAll(newEntries.idxToTypeVariable);

		/* two different implementations: 
		 * - if newEntries is small, we should check only the affected entries in result
		 * - if newEntries is large, we would probably need to replace everything anyway, so collecting affected types before is slower
		 * 
		 * as a guessed heuristic about 10% of entries will be affected, so let's do the first path if newEntries is smaller than 1/(10/100) result.
		 */
		if(newEntries.content.size <= 10 * result.content.size) {
			// if newEntries is REALLY small (guess: 5), hashmap lookup is slower than that many identity equals.
			val iterateInsteadOfBulkSubstitute = newEntries.content.size <= 5;
			val affectedIdxs = new IntOpenHashSet();
			for(int tvIdx: newEntries.content.keySet) {
				val newAffectedIdxs = oldEntries.tvHasThisFreeVar.remove(tvIdx)
				if(newAffectedIdxs !== null) {
					affectedIdxs.addAll(newAffectedIdxs);
				}
			}
			for(int typeIdx: affectedIdxs) {
				val vOld = oldEntries.content.get(typeIdx);
				val vNew = if(iterateInsteadOfBulkSubstitute) {
					var vNewTemp = vOld;
					for(k_v: newEntries.content.int2ObjectEntrySet) {
						val tv = newEntries.idxToTypeVariable.get(k_v.intKey);
						vNewTemp = vNewTemp.replace(tv, k_v.value)
					}
					vNewTemp;
				}
				else {
					vOld.replace(newEntries);
				}
				result.addToContent(oldEntries.idxToTypeVariable.get(typeIdx), vNew);	
			}
		}
		else {
			for(int k: result.content.keySet) {
				val vOld = result.content.get(k);
				val vNew = vOld.replace(newEntries);
				if(vOld !== vNew) {	
					add(idxToTypeVariable.get(k), vNew);	
				}
			}	
		}
		result.content.putAll(newEntries.content);
		for(k_v: newEntries.tvHasThisFreeVar.int2ObjectEntrySet) {
			// if somethings already there, we add all new ones
			// otherwise we put the set and `putIfAbsent` returns null, so the elvis isn't done.
			result.tvHasThisFreeVar.putIfAbsent(k_v.intKey, k_v.value)?.addAll(k_v.value);
		}
		
		return result;
	}
	
	def void addToContent(TypeVariable tv, AbstractType typ) {
		if(tv.idx == 6073) {
			print("")
		}
		content.put(tv.idx, typ);
		idxToTypeVariable.put(tv.idx, tv);
		val freeVars = typ.freeVars;
		for(fv: freeVars) {
			tvHasThisFreeVar.computeIfAbsent(fv.idx, [int __| new IntOpenHashSet()]).add(tv.idx);		
		}
	}
	
	def AbstractType applyToType(AbstractType typ) {
		typ.replace(this);
	}
	def Iterable<AbstractType> applyToTypes(Iterable<AbstractType> types) {
		return types.map[applyToType];
	}
	
	def apply(ConstraintSystem system) {
		return applyToNonAtomics(applyToAtomics(applyToGraph(system)));
	}
	
	def applyToGraph(ConstraintSystem system) {
		return applyToGraph(system, new DebugTimer(true));
	}
	def applyToGraph(ConstraintSystem system, DebugTimer debugTimer) {
		debugTimer.start("typeClasses")
		system.typeClasses.replaceAll[qn, tc | 
			tc.replace(this)
		];
		debugTimer.stop("typeClasses")
		
		debugTimer.start("explicitSubtypeRelations");
		system.explicitSubtypeRelationsTypeSource.replaceAll[tname, t | t.replace(this)];
		debugTimer.stop("explicitSubtypeRelations");
		
		return system;
	}
	
	def ConstraintSystem applyToAtomics(ConstraintSystem system) {
		applyToAtomics(system, new DebugTimer(true));
	}
	def ConstraintSystem applyToAtomics(ConstraintSystem system, DebugTimer debugTimer) {
		debugTimer.start("constraints");
		// atomic constraints may become composite by substitution, the opposite can't happen
		val unknownConstrains = system.atomicConstraints.map[c | c.replace(this)].force;
		debugTimer.stop("constraints");
		system.atomicConstraints.clear();
		debugTimer.start("atomicity");
		for(it: unknownConstrains) {
			if(it.isAtomic(system)) {
				system.atomicConstraints.add(it);
			}
			else {
				system.nonAtomicConstraints.add(it);
			}
		}
		debugTimer.stop("atomicity");
		return system;
	}
	def ConstraintSystem applyToNonAtomics(ConstraintSystem system) {
		system.nonAtomicConstraints.replaceAll[it.replace(this)];
		return system;
	}
	
	def Iterable<Pair<TypeVariable, AbstractType>> getSubstitutions() {
		return content.int2ObjectEntrySet.map[idxToTypeVariable.get(it.intKey) -> it.value];
	}
	
	public static final Substitution EMPTY = new Substitution() {
		
		override apply(Substitution to) {
			return to;
		}
				
		override applyMutating(Substitution oldEntries) {
			return oldEntries
		}
				
		override getContent() {
			return Int2ObjectMaps.unmodifiable(super.getContent());
		}
		override replace(TypeVariable from, AbstractType with) {
			return new Substitution() => [add(from, with)]
		}		
		override add(Iterable<Pair<TypeVariable, AbstractType>> content) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		override add(TypeVariable variable, AbstractType type) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		override add(Map<TypeVariable, AbstractType> content) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		override setContent(Int2ObjectMap<AbstractType> content) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
	}
	
	new(Substitution substitution) {
		this.constraintSystemProvider = substitution.constraintSystemProvider;
		this.content = new Int2ObjectOpenHashMap(substitution.content);
		this.idxToTypeVariable = new Int2ObjectOpenHashMap(substitution.idxToTypeVariable);
		this.tvHasThisFreeVar = new Int2ObjectOpenHashMap(substitution.tvHasThisFreeVar.size);
		for(k_v: substitution.tvHasThisFreeVar.int2ObjectEntrySet) {
			this.tvHasThisFreeVar.put(k_v.intKey, new IntOpenHashSet(k_v.value));
		}
	}
	
	new() {
	}
	
	override toString() {
		val sep = '\n'
		return content.int2ObjectEntrySet.map[ '''«it.intKey» ≔ «it.value»''' ].join(sep);
	}
	
}