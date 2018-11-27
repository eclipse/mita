package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
@Accessors
class ImplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType isInstance;
	protected final AbstractType ofType;
	
	new(AbstractType isInstance, AbstractType ofType, ValidationIssue errorMessage) {
		super(errorMessage);
		this.isInstance = isInstance;
		this.ofType = ofType;
		if(this.toString == "reference<i32> instanceof i32") {
			print("");
		}
	}
	
	override getErrorMessage() {
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, isInstance, ofType));
	}
	
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
		val newL = isInstance.map(f);
		val newR = ofType.map(f);
		if(isInstance !== newL || ofType !== newR) {
			return new ImplicitInstanceConstraint(isInstance.map(f), ofType.map(f), _errorMessage);
		}
		return this;
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
