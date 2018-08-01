package org.eclipse.mita.base.ui

import java.util.HashSet
import org.eclipse.emf.ecore.EObject
import org.eclipse.jface.text.ITextSelection
import org.eclipse.jface.viewers.ArrayContentProvider
import org.eclipse.jface.viewers.ColumnLabelProvider
import org.eclipse.jface.viewers.ISelection
import org.eclipse.jface.viewers.TableViewer
import org.eclipse.jface.viewers.TableViewerColumn
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.MitaResourceSet
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
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter

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
	
	protected def addConstraintsColumn(TableViewer viewer) {
		viewer.createTableViewerColumn("Left Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof EqualityConstraint) {
                	return element.left?.origin?.toString() ?: "null";
                } else if(element instanceof SubtypeConstraint) {
                	return element.subType?.origin?.toString() ?: "null";
                }
            }
            
        });
		viewer.createTableViewerColumn("Left", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof EqualityConstraint) {
                	return element.left?.toString() ?: "null";
                } else if(element instanceof SubtypeConstraint) {
                	return element.subType?.toString() ?: "null";
                }
            }
            
        });
        viewer.createTableViewerColumn("Operator", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof EqualityConstraint) {
                	return '≡';
                } else if(element instanceof SubtypeConstraint) {
                	return '⩽';
                }
            }
            
        });
        viewer.createTableViewerColumn("Right", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof EqualityConstraint) {
                	return element.right?.toString() ?: "null";
                } else if(element instanceof SubtypeConstraint) {
                	return element.superType?.toString() ?: "null";
                }
            }
            
        });
        viewer.createTableViewerColumn("Right Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                if(element instanceof EqualityConstraint) {
                	return element.right?.origin?.toString() ?: "null";
                } else if(element instanceof SubtypeConstraint) {
                	return element.superType?.origin?.toString() ?: "null";
                }
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
							val rs = state.resourceSet;
							if(rs instanceof MitaResourceSet) {
								updateViews(rs.latestSolution);
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
    		.filter[c| c.origins.exists[origin| objects.exists[obj| origin == obj ] ] ]
    		.toSet();
		this.constraintViewer.input = result;
    }
    
    protected def selectSolutions(Iterable<EObject> objects) {
    	if(constraintSolution === null) return;
    	
    	val substitution = constraintSolution.solution;
    	val input = constraintSolution.solution?.substitutions?.keySet;
    	if(input === null) {
    		return;
    	}
    	val origins = objects.map[TypeVariableAdapter.get(it)];

    	val result = origins.map[tv | tv -> substitution.apply(tv)];
    	
		this.solutionViewer.input = result.toSet;
    }
    
	protected def addIssueColumns(TableViewer viewer) {
		viewer.createTableViewerColumn("Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as UnificationIssue).origin?.toString() ?: "null";
            }
            
        });
        viewer.createTableViewerColumn("Message", 100, 1)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as UnificationIssue).message ?: "null";
            }
            
        });
	}
	
	protected def addSolutionColumns(TableViewer viewer) {
		viewer.createTableViewerColumn("Origin", 100, 0)
			.setLabelProvider(new ColumnLabelProvider() {
            
            override String getText(Object element) {
                return (element as Pair<TypeVariable, AbstractType>).key?.origin?.toString() ?: "null";
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