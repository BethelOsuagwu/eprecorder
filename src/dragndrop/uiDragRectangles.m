function uiDragRectangles(initialRectPositionXs,ax,fig,onChangeCallback)
    % Drag for figure based graphics
    % Number of rectangles to create

    if nargin<1
        initialRectPositionXs=[1,2;
                        2,3;
                        3,4;
                        4,5;
                        5,6];
    end

    if nargin<2
        fig=uifigure('handlevisibility', 'on');
        ax=uiaxes(fig);
        axis(ax,[0 10 0 10]);
        axis(ax,'manual');
        hold(ax,'on');
    end

    if nargin<3
        fig=[];
    end
    if nargin <4
        onChangeCallback=@(x) disp(x);
    end

    if isempty(fig)
        fig=ax.parent;
    end


    numRectangles = size(initialRectPositionXs,1);

    adjInitialRectPositionXs=initialRectPositionXs;
    adjInitialRectPositionXs(:,2)=initialRectPositionXs(:,2)-initialRectPositionXs(:,1);

    
    % Colors
    colors={[1,0,0,0.7],[0,0,1,0.6],[0,1,0,0.5],[1,1,0,0.4],[1,0,1,0.3]};
    
    
    % Create rectangles
    rectangles = createRectangles(numRectangles);
    
    % Initialize drag state variables
    isDragging = false;
    currentRectangle = 0;
    xOffset = 0;
    
    % Set mouse button down and up event handlers
    set(fig, 'WindowButtonDownFcn', @mouseButtonDown);
    set(fig, 'WindowButtonUpFcn', @mouseButtonUp);
    
    % Update rectangle position while dragging
    set(fig, 'WindowButtonMotionFcn', @mouseButtonMotion);
    
    function rectangles = createRectangles(numRectangles)
        rectangles = cell(1, numRectangles);

        for i = 1:numRectangles
            c=min([i,length(colors)]);
            x=adjInitialRectPositionXs(i,:);
            rectangleHandle = rectangle(ax,'Position', [x(1) 1 x(2) 1],'LineWidth',2,'EdgeColor',colors{c},"FaceColor",[0.5,0.5,0.5,0.1]);
            rectangles{i} = rectangleHandle;
        end
    end

    function mouseButtonDown(~, ~)
        rectangleHandles = rectangles;
        currentRectangle = find(cellfun(@(x) x == fig.CurrentObject, rectangleHandles));
        
        if ~isempty(currentRectangle)
            isDragging = true;
            rectPosition = rectangleHandles{currentRectangle}.Position;
            currentPoint = ax.CurrentPoint;
            xOffset = rectPosition(1) - currentPoint(1, 1);
        end
    end

    function mouseButtonUp(~, ~)
        if isDragging
            isDragging = false;
            emitChanges();
        end
    end

    function mouseButtonMotion(~, ~)
        if isDragging

            anchorPos=anchorPosition();
            switch(anchorPos)
                case 'between'
                    moveRectanglWestEast();
                case 'west'
                    adjustRectangleWest();
                case 'east'
                    adjustRectangleEast();
                otherwise 
                    error('Unknown achorPosition, %s',anchorPos)
            end

            drawnow;
            
        end
    end
    function emitChanges()
        % Emit the current positions of the rectangles

        % Get the rectangles' current positions
        rectangleHandles = rectangles;
        xs=zeros(numRectangles,2);
        for i = 1:numRectangles
            rectPosition = rectangleHandles{i}.Position;

            % Adjust the rectangle positions
            xs(i,:)=[rectPosition(1),rectPosition(1)+rectPosition(3)];
        end

        % Call the callback with adjusted rectangle positions.
        onChangeCallback(xs);
    end
    function adjustRectangleEast()
        currentPoint = ax.CurrentPoint;
        rect=getCurrentRectangle();
        
        rectPos=rect.Position;
        rectLeft=rect.Position(1);
        rectRight=rectLeft+rect.Position(3);
        xPosOffset=currentPoint(1,1)-rectRight;

        rectPos(3)=rectPos(3)+xPosOffset;


        rectangleHandles = rectangles;
        rectangleHandles{currentRectangle}.Position=rectPos;
    end

    function adjustRectangleWest()
        currentPoint = ax.CurrentPoint;
        rect = getCurrentRectangle();
        
        rectPos = rect.Position;
        rectLeft = rect.Position(1);
        xPosOffset = currentPoint(1, 1) - rectLeft;
        
        rectPos(1) = rectPos(1) + xPosOffset;
        rectPos(3) = rectPos(3) - xPosOffset;
        
        rectangleHandles = rectangles;
        rectangleHandles{currentRectangle}.Position = rectPos;
    end

    function moveRectanglWestEast()
        currentPoint = ax.CurrentPoint;
        newX = currentPoint(1, 1) + xOffset;
        newY = currentPoint(1, 2);
        
        rectangleHandles = rectangles;
        rectPosition = rectangleHandles{currentRectangle}.Position;
        rectPosition(1) = max(newX, 0); % Restrict rectangle movement within the x-axis
        rectangleHandles{currentRectangle}.Position = rectPosition;

    end

    function anchorPos= anchorPosition()
        % Determine the anchor position.
        % achorPos string: {east, west,between} 
        tol=0.15;% The absolute width at the left or right edge of a rectangle  considered to be part of the edge.

        currentPoint = ax.CurrentPoint;
        rect=getCurrentRectangle();

        rectLeft=rect.Position(1);
        rectRight=rectLeft+rect.Position(3);

        anchorPos='between';
        if currentPoint(1,1)-rectLeft < tol
            anchorPos='west';
        elseif currentPoint(1,1)-rectRight > -tol
            anchorPos='east';
        end
        
    end

    function rect=getCurrentRectangle()
        % Return the current rctangle an an object.
        rectangleHandles = rectangles;
        rect= rectangleHandles{currentRectangle};
    end
end
