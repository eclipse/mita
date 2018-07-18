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
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Program program) {
		println('''Prog: «program.eResource»''');
		system.computeConstraintsForChildren(program);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		system.computeConstraints(eventHandler.block);
		
		val voidType = system.symbolTable.content.get(StdlibTypeRegistry.voidTypeQID);
		val voidTypeAt = new AtomicType(voidType, "void");
		return system.associate(new FunctionType(eventHandler, voidTypeAt, voidTypeAt));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FunctionDefinition function) {
		system.computeConstraints(function.body);
			
		val fromType = system.computeParameterConstraints(function, function.parameters);
		val toType = system.computeConstraints(function.typeSpecifier);
		val result = system.associate(new FunctionType(function, fromType, toType));
		return result;
	}
	
	protected def computeParameterConstraints(ConstraintSystem system, FunctionDefinition function, ParameterList parms) {
		val parmTypes = parms.parameters.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].force();
		system.associate(new ProdType(parms, parmTypes));
	}
	
}