package org.eclipse.mita.program.typesystem

import org.eclipse.mita.base.types.ParameterList
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.Program

class ProgramConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Program prog) {
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
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		return new TypeVariable(eventHandler) => [typeVar |
			val voidType = system.symbolTable.content.get(StdlibTypeRegistry.voidTypeQID);
			val voidTypeAt = new AtomicType(voidType, "void");
			system.addConstraint(new Equality(typeVar, new FunctionType(eventHandler, voidTypeAt, voidTypeAt)));
			system.computeConstraints(eventHandler.block);
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FunctionDefinition function) {
		return new TypeVariable(function) => [typeVar |
			val fromType = system.computeParameterConstraints(function, function.parameters);
			val toType = system.computeConstraints(function.typeSpecifier);
			
			system.addConstraint(new Equality(typeVar, new FunctionType(function, fromType, toType)));
			
			system.computeConstraints(function.body);	
		]
	}
	
	def computeParameterConstraints(ConstraintSystem system, FunctionDefinition function, ParameterList parms) {
		return new TypeVariable(parms) => [typeVar |
			val parmTypes = parms.parameters.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].toList
			system.addConstraint(new Equality(typeVar, new ProdType(parms, parmTypes)))
		]
	}
	
}