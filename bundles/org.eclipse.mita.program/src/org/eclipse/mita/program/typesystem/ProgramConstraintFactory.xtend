package org.eclipse.mita.program.typesystem

import org.eclipse.emf.common.util.EList
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.ConstraintSystem
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AbstractTypeVariable
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.Program

class ProgramConstraintFactory extends BaseConstraintFactory {
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, Program prog) {
		prog.functionDefinitions.forEach[
			system.computeConstraints(it);
		]
		prog.types.forEach[
			system.computeConstraints(it);
		]
		prog.eventHandlers.forEach[
			system.computeConstraints(it);
		]
		return null;
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		return system.typeTable.introduce(eventHandler) => [typeVar |
			system.addConstraint(new Equality(typeVar, new FunctionType(StdlibTypeRegistry.voidType, StdlibTypeRegistry.voidType)));
		
			system.computeConstraints(eventHandler.block);
		]
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, FunctionDefinition function) {
		return system.typeTable.introduce(function) => [typeVar |
			val fromType = system.computeParameterConstraints(function, function.parameters);
			val toType = system.computeConstraints(function.typeSpecifier);
			
			system.addConstraint(new Equality(typeVar, new FunctionType(fromType, toType)));
			
			system.computeConstraints(function.body);	
		]
	}
	
	def computeParameterConstraints(ConstraintSystem system, FunctionDefinition function, EList<Parameter> parms) {
		return system.typeTable.introduce(nameProvider.getFullyQualifiedName(function).append('parameters')) => [typeVar |
			val parmTypes = parms.map[system.computeConstraints(it) as AbstractType]
			system.addConstraint(new Equality(typeVar, new ProdType(parmTypes)))
		]
	}
	
}