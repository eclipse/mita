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
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.types.Operation

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
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Operation function) {
		val typeArgs = function.typeParameters.map[system.computeConstraints(it)].force()
			
		val fromType = system.computeParameterConstraints(function, function.parameters);
		val toType = system.computeConstraints(function.typeSpecifier);
		val funType = new FunctionType(function, fromType, toType);
		var result = system.associate(	
			if(typeArgs.empty) {
				funType
			} else {
				new TypeScheme(function, typeArgs, funType);	
			}
		)
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FunctionDefinition function) {
		system.computeConstraints(function.body);
		system._computeConstraints(function as Operation);
	}
	
	protected def computeParameterConstraints(ConstraintSystem system, Operation function, ParameterList parms) {
		val parmTypes = parms.parameters.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].force();
		system.associate(new ProdType(parms, parmTypes));
	}
	
}