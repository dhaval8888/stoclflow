/**
 * Build consistent pagination parameters from query string.
 *
 * @param {object} query - req.query
 * @returns {{ limit: number, offset: number, page: number }}
 */
const getPagination = (query) => {
  const page  = Math.max(1, parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(query.limit, 10) || 20));
  const offset = (page - 1) * limit;
  return { page, limit, offset };
};

/**
 * Build the meta object returned in paginated list responses.
 *
 * @param {number} total - total record count from COUNT(*) query
 * @param {number} page
 * @param {number} limit
 * @returns {{ total: number, page: number, limit: number, totalPages: number, hasNext: boolean }}
 */
const buildMeta = (total, page, limit) => ({
  total,
  page,
  limit,
  totalPages: Math.ceil(total / limit),
  hasNext: page * limit < total,
  hasPrev: page > 1,
});

module.exports = { getPagination, buildMeta };
