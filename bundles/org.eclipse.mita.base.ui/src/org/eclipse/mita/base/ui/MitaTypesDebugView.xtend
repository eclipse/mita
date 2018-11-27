package org.eclipse.mita.base.ui

import java.util.HashSet
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.jface.text.ITextSelection
import org.eclipse.jface.viewers.ArrayContentProvider
import org.eclipse.jface.viewers.ColumnLabelProvider
import org.eclipse.jface.viewers.ISelection
import org.eclipse.jface.viewers.TableViewer
import org.eclipse.jface.viewers.TableViewerColumn
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.UnificationIssue
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.swt.SWT
import org.eclipse.swt.layout.FillLayout
import org.eclipse.swt.widgets.Composite
import org.eclipse.swt.widgets.Display
import org.eclipse.swt.widgets.TabFolder
import org.eclipse.swt.widgets.TabItem
import org.eclipse.ui.ISelectionListener
import org.eclipse.ui.IWorkbenchPart
import org.eclipse.ui.part.ViewPart
import org.eclipse.xtext.resource.EObjectAtOffsetHelper
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.ui.editor.XtextEditor
import org.eclipse.xtext.util.concurrent.IUnitOfWork

import static extension org.eclipse.mita.base.util.BaseUtils.force

class MitaTypesDebugView extends ViewPart {
	protected TableViewer constraintViewer;
	protected TableViewer solutionViewer;
	protected TableViewer issueViewer;
	protected ConstraintSolution constraintSolution;
	
	override createPartControl(Composite parent) {
		parent.layout = new FillLayout(SWT.HORIZONTAL.bitwiseOr(SWT.VERTICAL));
		val tabFolder = new TabFolder(parent, SWT.NONE);
		
		val constraintsItem = new TabItem(tabFolder, SWT.NONE);
		constraintsItem.text = "Constraints";
		val constraintsViewer = new TableViewer(tabFolder, SWT.MULTI);
		constraintsViewer.contentProvider = new ArrayContentProvider();
		constraintsViewer.addConstraintsColumn();
		val constraintsTable = constraintsViewer.getTable();
        constraintsTable.setHeaderVisible(true);
        constraintsTable.setLinesVisible(true);
        constraintsItem.control = constraintsTable;
        this.constraintViewer = constraintsViewer;
		
		val solutionItem = new TabItem(tabFolder, SWT.NONE);
		solutionItem.text = "Solution";
		val viewer = new TableViewer(tabFolder, SWT.MULTI);
		viewer.contentProvider = new ArrayContentProvider();
		viewer.addSolutionColumns();
		val table = viewer.getTable();
        table.setHeaderVisible(true);
        table.setLinesVisible(true);
        solutionItem.control = table;
        this.solutionViewer = viewer;
        
        val issuesItem = new TabItem(tabFolder, SWT.NONE);
		issuesItem.text = "Issues";
		val issuesViewer = new TableViewer(tabFolder);
		issuesViewer.contentProvider = new ArrayContentProvider();
		issuesViewer.addIssueColumns();
		val issueTable = issuesViewer.getTable();
        issueTable.setHeaderVisible(true);
        issueTable.setLinesVisible(true);
        issuesItem.control = issueTable;
        this.issueViewer = issuesViewer;
        
        getSite().getPage().addSelectionListener(listener);
	}
	
	protected def String originString(EObject origin) {
		if(origin !== null) {
			if(origin.eIsProxy) {
				if(origin instanceof EObjectImpl) {
					return origin.eProxyURI.fragment;
				}
			}
		}
		return origin?.toString() ?: "null"
	}
	
	protected def addConstraintsColumn(TableViewer viewer) {
		viewer.createTableViewerColumn("Left Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof AbstractTypeConstraint) {
                	val objects = element.members.toList;
                	if(objects.size > 0) {
                		val type = objects.get(0);
                		if(type instanceof AbstractType) {
                			return originString(type.origin)
                		}
                	}
                }
                return "";
            }
            
        });
		viewer.createTableViewerColumn("Left", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof AbstractTypeConstraint) {
                	val objects = element.members.toList;
                	if(objects.size > 0) {
                		return objects.get(0).toString();
                	}
                }
                return "";
            }
            
        });
        viewer.createTableViewerColumn("Operator", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                 if(element instanceof AbstractTypeConstraint) {
                	return element.operator;
                }
                return "";
            }
            
        });
        viewer.createTableViewerColumn("Right", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof AbstractTypeConstraint) {
                	val objects = element.members.toList;
                	if(objects.size > 1) {
                		return objects.get(1).toString();
                	}
                }
                return "";
            }
            
        });
        viewer.createTableViewerColumn("Right Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof AbstractTypeConstraint) {
                	val objects = element.members.toList;
                	if(objects.size > 1) {
                		val type = objects.get(1);
                		if(type instanceof AbstractType) {
                			return originString(type.origin)
                		}
                	}
                }
                return "";
            }
            
        });
        viewer.createTableViewerColumn("Error Message", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof AbstractTypeConstraint) {
                	return element.errorMessage.message
                }
                return "";
            }
            
        });
	}
	
	protected val listener = new ISelectionListener() {
		override void selectionChanged(IWorkbenchPart part, ISelection selection) {
			if(selection instanceof ITextSelection) {
				if(part instanceof XtextEditor) {
					val document = part.document;
					val offsetHelper = new EObjectAtOffsetHelper();
					document.readOnly(new IUnitOfWork<Object, XtextResource>() {
						override exec(XtextResource state) throws Exception {
							if(state instanceof MitaBaseResource) {
								updateViews(state.latestSolution);
							}
							
							val selectedObjects = new HashSet<EObject>();
							for(var i = 0; i < selection.length; i++) {
								val obj = offsetHelper.resolveContainedElementAt(state, selection.offset + i);
								if(obj !== null) {
									selectedObjects.add(obj);
								}
							}
							selectConstraints(selectedObjects);
							selectSolutions(selectedObjects);
							
							return null;
						}
					});
					
				}
			}
		}
	};
    
    protected def void updateViews(ConstraintSolution solution) {
    	if(solution === null) return;
    	
    	this.constraintSolution = solution;
    	Display.^default.asyncExec([
//    		this.constraintViewer.input = solution.constraints?.constraints ?: #[];
//    		this.solutionViewer.input = solution.solution?.substitutions?.entrySet ?: #[];
    		this.issueViewer.input =  solution.issues?.toArray() ?: #[];
    	]);
    }
    
    protected def selectConstraints(Iterable<EObject> objects) {
    	if(constraintSolution === null) return;
    	
    	val input = constraintSolution.constraints?.constraints;
    	if(input === null) {
    		return;
    	}
    	val origins = input
    		.map[ it as AbstractTypeConstraint ]
    	val result = origins
//    		.filter[c| c.origins.exists[origin| objects.exists[obj| origin == obj ] ] ]
//    		.toSet();
		this.constraintViewer.input = result;
    }
    
    protected def selectSolutions(Iterable<EObject> objects) {
    	if(constraintSolution === null) return;
    	
    	val substitution = constraintSolution.solution;
    	val input = constraintSolution.solution?.substitutions?.keySet;
    	val system = constraintSolution.constraints;
    	if(input === null) {
    		return;
    	}
    	val origins = objects.map[system.getTypeVariable(it)].force;

    	val result = origins.map[tv | tv -> substitution.apply(tv)].force;
    	
		this.solutionViewer.input = result.toSet;
    }
    
	protected def addIssueColumns(TableViewer viewer) {
		viewer.createTableViewerColumn("Severity", 100, 0).setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as ValidationIssue).severity?.toString() ?: "null";
            }
            
        });
		viewer.createTableViewerColumn("Origin", 100, 1)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return originString((element as ValidationIssue).target) ?: "null";
            }
            
        });
        viewer.createTableViewerColumn("Message", 100, 2)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as ValidationIssue).message ?: "null";
            }
            
        });
	}
	
	protected def addSolutionColumns(TableViewer viewer) {
		viewer.createTableViewerColumn("Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return ((element as Pair<TypeVariable, AbstractType>).key?.origin?.toString);
            }
            
        });
        viewer.createTableViewerColumn("Variable", 100, 1)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as Pair<TypeVariable, AbstractType>).key?.name?.toString() ?: "null";
            }
            
        });
        viewer.createTableViewerColumn("Binding", 100, 2)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as Pair<TypeVariable, AbstractType>).value?.toString() ?: "null";
            }
            
        });
	}
	
	static protected def createTableViewerColumn(TableViewer viewer, String title, int bound, int colNumber) {
        val viewerColumn = new TableViewerColumn(viewer, SWT.NONE);
        val column = viewerColumn.getColumn();
        column.setText(title);
        column.setWidth(bound);
        column.setResizable(true);
        column.setMoveable(true);
        return viewerColumn;
	}
	
	override setFocus() {
		
	}
	
	override dispose() {
		getSite().getPage().removeSelectionListener(listener);
		super.dispose();
	}
	
}