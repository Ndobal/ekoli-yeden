import type { RouteDefinition } from '../types/api';
import { requireAnyPermission } from '../middleware/auth';
import { hallOfFame, mapPlaces, setPlaceCoordinates } from '../controllers/discover.controller';
import { showQuiz, replaceQuestions, editorialQuestions } from '../controllers/learning.controller';

/**
 * DISCOVER EKORI, THE HALL OF FAME, AND LEARNING.
 *
 * The three sections of the proposal that needed an endpoint the generated
 * content routes could not express: a list gated on a community setting, a map
 * that must never invent a position, and a quiz that has to arrive with its
 * questions attached.
 *
 * ---------------------------------------------------------------------------
 * WHY THE PUBLIC ROUTES HERE ARE OPEN
 * ---------------------------------------------------------------------------
 *
 * All three read published rows only, and each hard-codes that in its own SQL
 * rather than accepting a parameter that could be left off. The Hall of Fame
 * additionally returns nothing at all until the community switches it on.
 */
export const discoverRoutes: RouteDefinition[] = [
  // --- Public --------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/hall-of-fame',
    handler: hallOfFame,
    description: 'The Hall of Fame, when the community has switched it on',
  },
  {
    method: 'GET',
    path: '/api/map/places',
    handler: mapPlaces,
    description: 'Every published place, and which of them have a recorded position',
  },
  {
    method: 'GET',
    path: '/api/learn/quizzes/:identifier',
    handler: showQuiz,
    description: 'One published quiz with its questions, marked in the browser',
  },

  // --- Editorial -----------------------------------------------------------
  //
  // Recording where a place stands is a heritage judgement rather than a media
  // one, so it sits with the people who look after history and the places tree.
  {
    method: 'POST',
    path: '/api/editorial/places/:id/coordinates',
    handler: setPlaceCoordinates,
    middleware: [requireAnyPermission(['history:update', 'people:update'])],
    description: 'Record or clear where a place actually is',
  },
  {
    method: 'GET',
    path: '/api/editorial/quizzes/:id/questions',
    handler: editorialQuestions,
    middleware: [requireAnyPermission(['language:update', 'pages:update'])],
    description: 'The question set as the composer needs it',
  },
  {
    method: 'PUT',
    path: '/api/editorial/quizzes/:id/questions',
    handler: replaceQuestions,
    middleware: [requireAnyPermission(['language:update', 'pages:update'])],
    description: 'Replace a quiz’s whole question set in one write',
  },
];
