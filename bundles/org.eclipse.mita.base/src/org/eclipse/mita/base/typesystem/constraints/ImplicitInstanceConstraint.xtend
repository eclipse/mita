package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor 
@EqualsHashCode
@Accessors
class ImplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType isInstance;
	protected final AbstractType ofType;
	
	override getActiveVars() {
		return types.flatMap[freeVars];
	}
	
	override getOrigins() {
		return types.map[origin];
	}
	
	override getTypes() {
		return #[isInstance, ofType];
	}
	
	override toGraphviz() {
		return "";
	}
	
	override toString() {
		return '''«isInstance» instanceof «ofType»'''
	}
	
	override map((AbstractType)=>AbstractType f) {
		return new ImplicitInstanceConstraint(isInstance.map(f), ofType.map(f));
	}
	
	override getOperator() {
		return "implicit instanceof"
	}
	
	override isAtomic() {
		val r1 = isInstance instanceof TypeVariable;
		val r2 = ofType instanceof TypeVariable;
		val r3 = r1 || r2;
		val r4 = isInstance != ofType;
		val r5 = r3 && r4;
		return (isInstance instanceof TypeVariable || ofType instanceof TypeVariable) 
			&& (isInstance != ofType)
	}
	
	
}
